"""dragon-search CLI. Prints action data only; never dispatches an action."""
import argparse
import json
import sys
from engine_common import result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['calc', 'cmd', 'web', 'emoji', 'emoji-use'])
    parser.add_argument('query', nargs='?', default='')
    parser.add_argument('--limit', type=int, default=20)
    parser.add_argument('--lang', choices=['es', 'en'], default='es')
    parser.add_argument('--json', action='store_true')
    arguments = list(sys.argv[1:] if argv is None else argv)
    # The quoted query is positional even when it begins with '-' (e.g. -2^2).
    if len(arguments) >= 2 and arguments[1].startswith('-') and arguments[1] not in ('--limit', '--lang', '--json', '--help', '-h'):
        arguments = arguments[:1] + arguments[2:] + ['--', arguments[1]]
    args = parser.parse_args(arguments)
    try:
        if args.mode == 'emoji-use':
            from search_emoji import use
            use(args.query)
            output = {'ok': True}
        else:
            if args.mode == 'calc':
                from search_calc import calculate
                value = calculate(args.query)
                rows = [] if value is None else [result('calc:1', value, args.query, 'calc', 'calc',
                                                        dict(type='copy', value=value), .98)]
            elif args.mode == 'cmd':
                from search_cmd import search
                rows = search(args.query, max(0, min(args.limit, 100)))
            elif args.mode == 'web':
                from search_web import search
                rows = search(args.query, args.lang)
            else:
                from search_emoji import search
                rows = search(args.query, args.lang)
            output = dict(mode=args.mode, query=args.query, results=rows[:max(0, min(args.limit, 100))])
        print(json.dumps(output, ensure_ascii=False, allow_nan=False))
        return 0
    except Exception as error:
        print(json.dumps({'error': str(error)}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    sys.exit(main())
