#ifndef ulc_object_h
#define ulc_object_h

#include "ulc_symtable.h"

typedef struct function {
	char id[NAME_MLEN];
	long ret;
} TFunction;

typedef struct jmplabel {
	long addr_goto;
	long addr_goto_false;
} TJmpLabel;

typedef enum type {
	TYPE_NUMBER,
	TYPE_STRING
} TType;

typedef struct value {
	long val;
	TType type;
} TValue;

#endif