"""Bounded recursive-descent arithmetic; no Python expression execution."""
import math
import re
import time

MAX_VALUE = 1e100
NUMBER = r'(?:\d+(?:[.,]\d*)?|[.,]\d+)(?:[eE][+-]?\d+)?'
LEXER = re.compile(r'\s*(0[xX][0-9a-fA-F]+|0[bB][01]+|' + NUMBER + r'|[a-zA-Z]+|[-+*/^%();])')
FUNCTIONS = dict(sqrt=math.sqrt, sin=math.sin, cos=math.cos, tan=math.tan,
                 log=math.log10, ln=math.log, abs=abs, round=round)


class Invalid(ValueError):
    pass


def bounded(value):
    if not isinstance(value, (int, float)) or not math.isfinite(value) or abs(value) > MAX_VALUE:
        raise Invalid('result too large')
    return value


class Parser:
    def __init__(self, text):
        self.deadline = time.monotonic() + .035
        self.tokens = []
        position = 0
        while position < len(text):
            match = LEXER.match(text, position)
            if not match:
                if not text[position:].strip():
                    break
                raise Invalid('token')
            self.tokens.append(match[1].lower())
            position = match.end()
            if len(self.tokens) > 160:
                raise Invalid('tokens')
        self.tokens.append('end')
        self.index = 0

    def pop(self):
        if time.monotonic() > self.deadline:
            raise Invalid('time')
        token = self.tokens[self.index]
        self.index += 1
        return token

    def peek(self):
        return self.tokens[self.index]

    def expression(self, minimum=0):
        token = self.pop()
        percentage = False
        if token in ('+', '-'):
            value, percentage = self.expression(25)
            value *= -1 if token == '-' else 1
        elif token == '(':
            value, percentage = self.expression()
            if self.pop() != ')':
                raise Invalid('parentheses')
        elif token in FUNCTIONS:
            if self.pop() != '(':
                raise Invalid('function')
            argument, _ = self.expression()
            if token == 'round' and self.peek() == ';':
                self.pop()
                digits, _ = self.expression()
                if int(digits) != digits or abs(digits) > 20:
                    raise Invalid('round precision')
                value = round(argument, int(digits))
            else:
                value = FUNCTIONS[token](argument)
            if self.pop() != ')':
                raise Invalid('function end')
        elif token in ('pi', 'e'):
            value = math.pi if token == 'pi' else math.e
        elif re.fullmatch(r'0x[0-9a-f]+|0b[01]+', token):
            value = int(token, 0)
        else:
            try:
                value = float(token.replace(',', '.'))
            except ValueError as error:
                raise Invalid('number') from error
        bounded(value)
        while True:
            operator = self.peek()
            # % with a following primary is modulo; at an expression boundary it is percent.
            if operator == '%' and (self.tokens[self.index + 1] == 'end' or not re.match(r'^(?:\d|[a-z]|[.(])', self.tokens[self.index + 1])):
                if 40 < minimum:
                    break
                self.pop()
                value /= 100
                percentage = True
                continue
            precedence = {'+': 10, '-': 10, '*': 20, '/': 20, '%': 20, '^': 30}.get(operator, -1)
            if precedence < minimum:
                break
            self.pop()
            right, relative = self.expression(precedence if operator == '^' else precedence + 1)
            if operator == '+':
                value += value * right if relative else right
            elif operator == '-':
                value -= value * right if relative else right
            elif operator == '*':
                value *= right
            elif operator == '/':
                value /= right
            elif operator == '%':
                value %= right
            else:
                if abs(right) > 1024 or (value and abs(value) != 1 and right * math.log10(abs(value)) > 100):
                    raise Invalid('power bound')
                value = math.pow(value, right)
            bounded(value)
            percentage = False
        return value, percentage

    def parse(self):
        value, _ = self.expression()
        if self.peek() != 'end':
            raise Invalid('trailing input')
        return value


UNITS = {}


def units(dimension, factor, *names, offset=0):
    for name in names:
        UNITS[name] = (dimension, factor, offset)


units('length', 1, 'm', 'metro', 'metros', 'meter', 'meters')
units('length', .001, 'mm', 'milimetro', 'milimetros')
units('length', .01, 'cm', 'centimetro', 'centimetros')
units('length', 1000, 'km', 'kilometro', 'kilometros')
units('length', .0254, 'in', 'inch', 'inches', 'pulgada', 'pulgadas')
units('length', .3048, 'ft', 'foot', 'feet', 'pie', 'pies')
units('length', .9144, 'yd', 'yarda', 'yardas')
units('length', 1609.344, 'mi', 'mile', 'miles', 'milla', 'millas')
units('mass', 1, 'kg', 'kilogramo', 'kilogramos')
units('mass', .001, 'g', 'gramo', 'gramos')
units('mass', .000001, 'mg')
units('mass', .45359237, 'lb', 'lbs', 'libra', 'libras', 'pound', 'pounds')
units('mass', .028349523125, 'oz', 'onza', 'onzas')
units('volume', 1, 'l', 'litro', 'litros', 'liter', 'liters')
units('volume', .001, 'ml', 'mililitro', 'mililitros')
units('volume', 3.785411784, 'gal', 'gallon', 'galon', 'galones')
units('volume', .2365882365, 'cup', 'cups', 'taza', 'tazas')
units('time', 1, 's', 'sec', 'segundo', 'segundos', 'second', 'seconds')
units('time', .001, 'ms')
units('time', 60, 'min', 'minuto', 'minutos', 'minute', 'minutes')
units('time', 3600, 'h', 'hora', 'horas', 'hour', 'hours')
units('time', 86400, 'd', 'dia', 'dias', 'day', 'days')
units('time', 604800, 'semana', 'semanas', 'week', 'weeks')
units('temperature', 1, 'c', '°c', 'celsius')
units('temperature', 5 / 9, 'f', '°f', 'fahrenheit', offset=-32 * 5 / 9)
units('temperature', 1, 'k', 'kelvin', offset=-273.15)
units('data', 1, 'b', 'byte', 'bytes')
units('data', .125, 'bit', 'bits')
for power, prefix in enumerate(('k', 'm', 'g', 't', 'p'), 1):
    units('data', 1000 ** power, prefix + 'b')
    units('data', 1024 ** power, prefix + 'ib')


def clean(value):
    bounded(value)
    if abs(value) < 1e-14:
        value = 0
    return format(value, '.12g')


def calculate(query):
    if not query.strip() or len(query) > 1024:
        return None
    from engine_common import folded
    text = folded(query).strip()
    try:
        base = re.fullmatch(r'([0-9a-fxob]+)\s+(?:a|to|en)\s+(hex|hexadecimal|decimal|dec|bin|binario|binary)', text)
        if base:
            raw, target = base.groups()
            value = int(raw, 0) if raw.startswith(('0x', '0b')) else int(raw, 16 if re.search('[a-f]', raw) else 10)
            bounded(value)
            return hex(value) if target in ('hex', 'hexadecimal') else bin(value) if target in ('bin', 'binario', 'binary') else str(value)
        conversion = re.fullmatch(r'(.+?)\s*([a-z°]+)\s+(?:a|to|en|in|->)\s+([a-z°]+)', text)
        if conversion:
            expression, source, target = conversion.groups()
            dimension, factor, offset = UNITS[source]
            other, divisor, shift = UNITS[target]
            if dimension != other:
                return None
            value = (Parser(expression).parse() * factor + offset - shift) / divisor
            return clean(value)
        text = re.sub(r'%\s*(?:de\s+propina\s+sobre|de|of|tip\s+on)\s+', '% * ', text)
        return clean(Parser(text).parse())
    except (ValueError, KeyError, OverflowError, ZeroDivisionError, IndexError, RecursionError):
        return None
