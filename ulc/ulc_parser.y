%{

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "ulc_codegen.h"
#include "ulc_environ.h"
#include "ulc_object.h"
#include "ulc_vm.h"
#include "util.h"

extern int yylex();
extern void yyerror(const char *s);
extern int yylineno;

// Some scratch area
static char* name_aux;

//TODO error reporting
inline static void
check_gen_code(OpCode opcode, const char *name)
{
        Symbol *s = NULL;
        if(!(s = get_symbol(name, true)))
            fprintf(stderr, "Undefined symbol: %s\n", name);
        else {
            switch(s->kind) {
                case Sym_Func:
                    gen_code(opcode, label_data(), s->addr);
                    break;
                case Sym_Global:
                    gen_code(opcode, 0, s->addr);
                    break;
                case Sym_Local:
                    gen_code(opcode, label_data(), s->addr);
                    break;
            }
        }
}

%}

%union{
    char* id;
    long litnum;
    TType     type;
    TValue    litv;
    TJmpLabel lbls;
    TFunction func;
}

%token <id> TK_MAIN
%token <id> TK_NAME
%token <type> TK_DATA
%token <type> TK_FUNC
%token <litnum> TK_LIT_NUM
%token <litnum> TK_LIT_STR
%token TK_COMMA TK_SCOLON
%token TK_LBRACK TK_RBRACK
%token TK_LPAREN TK_RPAREN
%token TK_LBRACE TK_RBRACE
%token TK_RETURN TK_READ TK_WRITE
%token <lbls> TK_IF TK_WHILE
%token TK_ELSE
%token TK_ASSIGN
%token TK_OR TK_AND TK_EQ TK_NEQ
%token TK_LT TK_MT TK_LE TK_ME
%token TK_ADD TK_SUB TK_MULT TK_DIV TK_MOD
%token TK_NEG

/* flag token to signal unterminated comments from the scanner */
%token COMMENT_ERROR;

/* start symbol */
%start prog

%%

prog: /* a program is made of...*/
      {push_scope(label_data());}
      /* data and function declarations followed by */
      datadecl funcdecl
      /* a program main declaration */
      progdecl
      {gen_code(HLT, 0, 0); pop_scope(); YYACCEPT;}
;

/* data declaration */
datadecl: /* empty or */
        | TK_DATA TK_NAME {
            add_symbol($2, Sym_Global, alloc_data());
          } datadeclcont TK_SCOLON datadecl
        | TK_DATA TK_NAME TK_ASSIGN expr {
            add_symbol($2, Sym_Global, alloc_data());
            check_gen_code(STO, $2);
          } datadeclcont TK_SCOLON datadecl
          /* TODO */
        | TK_DATA TK_NAME TK_LBRACK TK_LIT_NUM TK_RBRACK datadeclcont TK_SCOLON datadecl
;

datadeclcont: /* empty or */
            | TK_COMMA TK_NAME {
                add_symbol($2, Sym_Global, alloc_data());
              } datadeclcont
            | TK_COMMA TK_NAME TK_ASSIGN expr {
                add_symbol($2, Sym_Global, alloc_data());
                check_gen_code(STO, $2);
              } datadeclcont
              /* TODO */
            | TK_COMMA TK_NAME TK_LBRACK TK_LIT_NUM TK_RBRACK datadeclcont
;

/* functions */
funcdecl: /* empty or */
        | TK_NAME {name_aux = $1;} TK_LPAREN {
            add_symbol($1, Sym_Func, label_code());
            push_scope(label_data()); // enter new scope before parameters decl
          } paramlist TK_RPAREN block {pop_scope();} funcdecl


paramlist: /* empty or */
         | paramlistcont
;

paramlistcont:
               TK_DATA TK_NAME {
                  Symbol* s = get_symbol(name_aux, true);
                  add_symbol($2, Sym_Local, ++s->u.func.nl);
               }
             | TK_DATA TK_NAME TK_COMMA {
                  Symbol* s = get_symbol(name_aux, true);
                  add_symbol($2, Sym_Local, ++s->u.func.nl);
               } paramlistcont
               /* TODO */
             | TK_DATA TK_NAME TK_LBRACK TK_RBRACK
             | TK_DATA TK_NAME TK_LBRACK TK_RBRACK TK_COMMA paramlistcont
;

progdecl:
          TK_MAIN {
            name_aux = $1;
            add_symbol($1, Sym_Func, label_code());
            push_scope(label_data());
            set_main_offset(label_code());
          } block {pop_scope();}
;

block:
       TK_LBRACE {push_scope(label_data());} localdata commlist TK_RBRACE {pop_scope();}
     | TK_LBRACE TK_RBRACE
;

/* local data declaration */
localdata: /* empty or */
           | TK_DATA TK_NAME {
                 Symbol* s = get_symbol(name_aux, true);
                 add_symbol($2, Sym_Local, ++s->u.func.nl);
             } localdatacont TK_SCOLON localdata
           | TK_DATA TK_NAME TK_ASSIGN expr {
                Symbol* s = get_symbol(name_aux, true);
                add_symbol($2, Sym_Local, ++s->u.func.nl);
                check_gen_code(STO, $2);
             } localdatacont TK_SCOLON localdata
             /* TODO */
           | TK_DATA TK_NAME TK_LBRACK TK_LIT_NUM TK_RBRACK localdatacont TK_SCOLON localdata
;

localdatacont: /* empty or */
            | TK_COMMA TK_NAME {
                Symbol* s = get_symbol(name_aux, true);
                add_symbol($2, Sym_Local, ++s->u.func.nl);
              } localdatacont
            | TK_COMMA TK_NAME TK_ASSIGN expr {
                Symbol* s = get_symbol(name_aux, true);
                add_symbol($2, Sym_Local, ++s->u.func.nl);
                check_gen_code(STO, $2);
              } localdatacont
              /* TODO */
            | TK_COMMA TK_NAME TK_LBRACK TK_LIT_NUM TK_RBRACK localdatacont
;

commlist:
          comm
        | comm commlist
;

comm:
       TK_SCOLON
     | expr TK_SCOLON
     | TK_RETURN expr TK_SCOLON {gen_code(RET, 0, 0);}
     | TK_READ lvalexpr {check_gen_code(IN, $<id>2);} readvars TK_SCOLON
     | TK_WRITE expr TK_SCOLON {gen_code(OUT, 0, 0);}
     | ifstmt
     | ifstmt TK_ELSE comm {back_patch($<lbls>$.addr_goto, JMP, label_code());}
     | TK_WHILE TK_LPAREN {$1.addr_goto = label_code();} expr {$1.addr_goto_false = alloc_code();} TK_RPAREN comm {gen_code(JMP, 0, $1.addr_goto);back_patch($1.addr_goto_false, JMPZ, label_code()); }
     | block
;

readvars: /* empty or */
        | TK_COMMA lvalexpr readvars {check_gen_code(IN, $<id>2);}
;

ifstmt:
        TK_IF TK_LPAREN expr TK_RPAREN {$1.addr_goto_false = alloc_code();} comm {$1.addr_goto = alloc_code(); $<lbls>$ = $1; back_patch($1.addr_goto_false, JMPZ, label_code()); back_patch($1.addr_goto, JMP, label_code());}
;

expr:
      assignexpr
    | TK_READ {gen_code(IN, -1, 0);}
;

assignexpr: orexpr
          | lvalexpr TK_ASSIGN assignexpr {check_gen_code(STO, $<id>1);}
;

orexpr:
        andexpr
      | orexpr TK_OR andexpr {gen_code(OR, 0, 0);}
;

andexpr:
         eqexpr
       | andexpr TK_AND eqexpr {gen_code(AND, 0, 0);}
;

eqexpr:
        ineqexpr
      | eqexpr TK_EQ ineqexpr {gen_code(EQ, 0, 0);}
      | eqexpr TK_NEQ ineqexpr {gen_code(NEQ, 0, 0);}
;

ineqexpr:
         addexpr
       | ineqexpr TK_LT addexpr {gen_code(LT, 0, 0);}
       | ineqexpr TK_MT addexpr {gen_code(GT, 0, 0);}
       | ineqexpr TK_LE addexpr {gen_code(LE, 0, 0);}
       | ineqexpr TK_ME addexpr {gen_code(GE, 0, 0);}
;

addexpr:
         multexpr
       | addexpr TK_ADD multexpr {gen_code(ADD, 0, 0);}
       | addexpr TK_SUB multexpr {gen_code(SUB, 0, 0);}
;

multexpr:
          unexpr
        | multexpr TK_MULT unexpr {gen_code(MUL, 0, 0);}
        | multexpr TK_DIV unexpr {gen_code(DIV, 0, 0);}
        | multexpr TK_MOD unexpr {gen_code(MOD, 0, 0);}
;

unexpr:
        primexpr
      | TK_SUB primexpr {gen_code(NEG, 0, 0);}
      | TK_NEG primexpr {gen_code(NOT, 0, 0);}
;

lvalexpr:
          TK_NAME {$<id>$ = strdup($1);}
        | TK_NAME TK_LBRACK expr TK_RBRACK
;

primexpr:
          TK_NAME {check_gen_code(LODV, $1);}
          /* function call */
        | TK_NAME TK_LPAREN {
            $<func>2.id = strdup($1); // save name
            $<func>2.ret = alloc_code(); // mark return adderss
          } exprlist TK_RPAREN {
            check_gen_code(CALL, $<func>2.id); // call function
            back_patch($<func>2.ret, LODI, label_code()); // LODI ret addr
          }
          /* TODO */
        | TK_NAME TK_LBRACK expr TK_RBRACK
        | TK_LPAREN expr TK_RPAREN
        | TK_LIT_NUM {gen_code(LODI, 0, $1);}
          /* TODO */
        | TK_LIT_STR
;

exprlist:
          assignexpr
        | exprlist TK_COMMA assignexpr
        |
;

%%

void
yyerror(const char *s) 
{
    switch(yychar) {
        case COMMENT_ERROR:
            fprintf(stderr, "%s:" KRED " error" KNRM " at line %d: unterminated comment\n",
                getprogname(), yylineno);
            yychar = YYEOF;
            break;
        default:
            fprintf(stderr, "%s:" KRED " error" KNRM " at line %d: %s\n",
                getprogname(), yylineno, s);
            break;
    }
}
