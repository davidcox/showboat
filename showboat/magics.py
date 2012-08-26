from pyparsing import *
from copy import copy
import functools

registry = {}


class Value (object):
    def __init__(self, v):
        self.v = v


class MagicCmd (object):
    def __init__(self, indent, name, args, kwargs, rest_of_line):
        self.name = name
        self.args = list(args)
        self.kwargs = dict(list(kwargs))
        self.content_after = rest_of_line
        self.content_under = ''
        self.indent = indent

    def transform(self, fn_registry):
        if self.name in fn_registry:
            args = copy(self.args)
            kwargs = copy(self.kwargs)
            kwargs['content_after'] = self.content_after
            kwargs['content_under'] = self.content_under
            kwargs['indent_level'] = self.indent
            kwargs['magic_name'] = self.name
            return fn_registry[self.name](*args, **kwargs)
        else:
            raise ValueError('Not a valid magic function name: %s' % (self.name))

    def __repr__(self):
        return ('INDENT: (%s), ID: %s, ARGS: %s, KWARGS: %s, REST: "%s", UNDER: %s' %
                (self.indent, self.name, self.args, self.kwargs, self.content_after,
                 self.content_under))

magic_char = Suppress('@')
lparen = Suppress('(')
rparen = Suppress(')')
identifier = Word(alphanums + '_')
comma = Suppress(',')
line_start = Suppress(Regex(r'\n'))
indent = Regex(r'[ \t]*').leaveWhitespace()
indented_line = line_start + indent + Suppress(Regex(r'\S'))
indented_line.setWhitespaceChars('')

magic_invoke = (line_start + indent('indent') +
                magic_char + identifier('id'))
magic_invoke.setWhitespaceChars(' \t')

qstring = QuotedString('"') | QuotedString("'")
value = qstring

parg_list = delimitedList(value)('args')

kwarg_pair = identifier('k') + Suppress('=') + value('v')
kwarg_pair.setParseAction(lambda x: (x.k, x.v))
kwarg_list = delimitedList(kwarg_pair)('kwargs')

mixed_arg_list = lparen + parg_list + comma + kwarg_list + rparen
just_parg_list = lparen + parg_list + rparen
just_kwarg_list = lparen + kwarg_list + rparen
empty_arg_list = lparen + rparen

arg_list = empty_arg_list | mixed_arg_list | just_parg_list | just_kwarg_list

magic_cmd = magic_invoke + Optional(arg_list) + SkipTo(LineEnd())('rest')
magic_cmd.setParseAction(lambda x: MagicCmd(x.indent, x.id,
                                            x.args, x.kwargs, x.rest))


def pad_str(s):
    return '\n' + s


def unpad_str(s):
    return s[1:]


def recursive_evaluate_magics(s, fn_registry):

    s = pad_str(s)

    # find the first magic invokation
    try:
        m, mstart, mend = magic_cmd.scanString(s).next()
    except StopIteration:
        return unpad_str(s)

    magic_obj = m[0]

    # scan for indents, we'll bail at the first one less than
    # the indent level of the current magic
    target_indent = len(magic_obj.indent)
    content_under_end = len(s)
    for i, istart, iend in indented_line.scanString(s[mend:]):
        this_indent = len(i[0])
        if this_indent <= target_indent:
            content_under_end = mend + istart
            break

    content_under = s[mend + 1:content_under_end]

    magic_obj.content_under = recursive_evaluate_magics(content_under, fn_registry)
    # execute the magic
    result = magic_obj.transform(registry)

    # the part before the magic command
    pre = s[0:mstart] + '\n' + magic_obj.indent

    # everything after the close of the magic
    post = s[content_under_end:]

    new_string = pre + result + post
    return unpad_str(recursive_evaluate_magics(new_string, fn_registry))

def magic_function(arg=None):

    def plain_decorator(fn, fn_name=None):
        if fn_name is None:
            registry[fn.__name__] = fn
        else:
            registry[fn_name] = fn

        return fn

    # hacky: if 'name' is actually a function, then this is an arg-less decorator
    if type(arg) == type(plain_decorator):
        return plain_decorator(arg)

    return functools.partial(plain_decorator, fn_name=arg)


class magic_decorator (object):

    def __init__(self, name=None):
        self.name = name

    def __call__(self, fn):
        if self.name is None:
            self.name = fn.__name__
        print 'registering: %s' % self.name
        registry[self.name] = fn

        return fn


def linewise_prefix(content, prefix):
    lines = content.split('\n')
    prefixed = [prefix + l for l in lines]
    return '\n'.join(prefixed)


def register_magic_identity_function(name, prefix=''):
    'Register a magic function that simply strips of the magic char'

    def magic_identity(*args, **kwargs):
        content_after = kwargs.pop('content_after', '')
        content_under = kwargs.pop('content_under', '')
        indent_level = kwargs.pop('indent_level', 0)
        magic_name = kwargs.pop('magic_name', 'identity')

        arg_list = ''

        if len(args) or len(kwargs.items()):
            arg_list += '('

        if len(args) > 0:
            arg_list += ', '.join([str(x) for x in args]) + ' '

        if len(kwargs.items()):
            arg_list += ', '.join([str(x) + "='" + str(y) + "'" for x, y in kwargs.items()])

        if len(args) or len(kwargs.items()):
            arg_list += ')'

        indent = indent_level
        processed = (indent + prefix + magic_name +
                            arg_list + ' ' + content_after + '\n' +
                            content_under)

        return processed

    return magic_function(name)(magic_identity)


@magic_function
def blah3(a1, a2, **kwargs):
    #print('calling blah3')
    after = kwargs.pop('content_after')
    under = kwargs.pop('content_under')

    s = "BLAH3 magic was here: %s, %s" % (a1, a2)
    s += "\nit had some kwargs: %s" % kwargs
    s += "\n and an after: %s" % after
    s += "\n and some under stuff: %s" % under

    #print "returning %s" % s
    return s


@magic_function
def blah7(**kwargs):
    return "BLAH7" + ' ' + kwargs['content_after'].upper()


@magic_function
def blah4(**kwargs):
    return "BLAH4" + ' {\n' + kwargs['content_under'] + '}'

register_magic_identity_function('iden_test')

def parse_magics(s):
    return recursive_evaluate_magics(s, registry)

def test_magics(s):
    print 'TEST STRING: '
    print s
    print '___________________'
    print ''
    print 'TRANSFORMED:'
    print parse_magics(s)

if __name__ == '__main__':

    test_str = """

@blah3('arg', 'arg2',
       something='somethingelse')
    blah6
    @blah7 blah
        deeper
    blah12
blah
    blah8 bleee blee
blah2
@blah4
blah5
    """

    test_str = """
@blah4
    @iden_test balh
        stuff
    should_be_unindented
    should be unindented 2
"""

    test_magics(test_str)
