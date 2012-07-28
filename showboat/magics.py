from pyparsing import *
from copy import copy

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

    def __call__(self, fn_registry):
        if self.name in fn_registry:
            args = copy(self.args)
            kwargs = copy(self.kwargs)
            kwargs['content_after'] = self.content_after
            kwargs['content_under'] = self.content_under
            print "!", self.content_under
            return fn_registry[self.name](*args, **kwargs)
        else:
            raise ValueError('Not a valid magic function name')

    def __repr__(self):
        return ('INDENT: (%s), ID: %s, ARGS: %s, KWARGS: %s, REST: "%s", UNDER: %s' %
                (self.indent, self.name, self.args, self.kwargs, self.content_after,
                 self.content_under))

magic_char = Suppress('@')
lparen = Suppress('(')
rparen = Suppress(')')
identifier = Word(alphanums)
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


def recursive_evaluate_magics(s, fn_registry):

    # find the first magic invokation
    try:
        m, mstart, mend = magic_cmd.scanString(s).next()
    except StopIteration:
        return s

    magic_obj = m[0]

    # scan for indents, we'll bail at the first one less than
    # the indent level of the current magic
    target_indent = len(m.indent_level)
    content_under_end = len(s)
    for i, istart, iend in indented_line.scanString(s[mend:]):
        this_indent = len(i[0])
        print "target:", target_indent
        print "this indent:", this_indent
        if this_indent <= target_indent:
            content_under_end = mend + istart
            break

    magic_obj.content_under = s[mend:content_under_end]
    print "Content under: {%s}" % magic_obj.content_under

    print 'Found magic: %s' % m

    # execute the magic
    result = magic_obj(registry)

    pre = s[0:mstart]
    post = s[content_under_end:]

    return recursive_evaluate_magics(pre + result + post, fn_registry)


def magic_function(fn):
    registry[fn.__name__] = fn

    return fn


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
    return "BLAH7" + kwargs['content_after'].upper()


@magic_function
def blah4(**kwargs):
    print kwargs
    return "BLAH4" + kwargs['content_under']


def parse_magics(s):

    print recursive_evaluate_magics(s, registry)


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
    stuff
    @blah7 this
"""

    parse_magics(test_str)
