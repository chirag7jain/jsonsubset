from json_parser_values cimport *

cdef class Parser:
    """
    This class concentrates all parser state and parsing methods for each type
    """

    def __cinit__(self, bytes json_bytes_python, expr, int expr_len):
        self.json_bytes_python = json_bytes_python
        self.json_bytes = self.i = json_bytes_python
        self.json_bytes_len = len(json_bytes_python)
        self.expr = expr

        # optimisation: if num_parsed == expr_len (i.e. if we already parsed
        # all statements set as True in the expression), we can stop parsing
        self.num_parsed = 0
        self.expr_len = expr_len

    cpdef object parse(self):
        return self._parse(self.expr)

    cdef object _parse(self, object expr):
        cdef char c = self.consume()

        if c == b'{':
            value = self._parse_obj(expr)

        elif c == b'"':
            value = self._parse_str()

        elif c == b'[':
            value = self._parse_array()

        elif c in (b't', b'f'): # 't' -> "true", 'f' -> "false"
            value = self._parse_bool()

        elif b'-' <= c <= b'9' or c in (b'I', b'N'): # 'I' -> "Infinity", 'N' -> "NaN"
            value = self._parse_num()

        elif c == b'n': # 'n' -> "null"
            value = self._parse_null()

        else:
            # bug (or invalid json)
            assert False, (chr(self.last), self.json_bytes, self.i-self.json_bytes, len(self.json_bytes), chr(self.i[0]))

        if expr is True:
            self.num_parsed += 1
            return value.get()

        elif expr is not False:
            return value.get()

        self.last = c

    cdef ObjectValue _parse_obj(self, expr):
        cdef ObjectValue ret = ObjectValue()
        ret.start = self.i
        self.i += 1

        if expr is not False:
            ret.obj = {}

        cdef StringValue key
        cdef unsigned long long key_hash
        cdef str key_str

        while (self.consume() != b'}') and (self.num_parsed < self.expr_len):
            key = self._parse_str()
            key_hash = key.hash()

            self.i += 1

            self.consume() # consume ':'
            self.i += 1

            if expr is True or expr is 1:
                key_str = key.get()
                # using 1 instead of True to avoid self.num_parsed increment
                ret.obj[key_str] = self._parse(1)

            elif (expr is False) or (key_hash not in expr):
                self._parse(False)

            else:
                key_str = key.get()
                ret.obj[key_str] = self._parse(expr[key_hash])

            self.i += 1

            if self.consume() == b',':
                self.i += 1


        ret.end = self.i
        return ret

    cdef StringValue _parse_str(self):
        cdef StringValue ret = StringValue()

        ret.safe = 1
        ret.start = self.i
        self.i += 1

        while self.i[0] != b'"':
            if self.i[0] == b'\\': #escaped char
                ret.safe = 0
                self.i += 2

            else:
                self.i += 1

        ret.end = self.i

        return ret

    cdef Value _parse_array(self):
        cdef Value ret = Value()
        ret.start = self.i
        self.i += 1

        while self.consume() != b']' and self.num_parsed < self.expr_len:
            self._parse(False)
            self.i += 1

            if self.consume() == b',':
                self.i += 1

        ret.end=self.i
        return ret

    cdef NumberValue _parse_num(self):
        cdef NumberValue ret = NumberValue()
        ret.start = self.i

        while (self.i[1] not in b' ,\x00}]'):
            self.i += 1

        ret.end = self.i
        return ret

    cdef NullValue _parse_null(self):
        cdef NullValue ret = NullValue()
        ret.start = self.i

        self.i += 3 # == len("null") - 1

        ret.end = self.i
        return ret

    cdef _parse_bool(self):
        cdef Value ret = Value()
        ret.start = self.i

        if self.i[0] == b't':
            self.i += 3 # == len("true") - 1

        elif self.i[0] == b'f':
            self.i += 4 # == len("false") - 1

        ret.end = self.i
        return ret

    cdef char consume(self):
        # just get next non-space character
        while self.i[0] == b' ':
            self.i += 1

        return self.i[0]