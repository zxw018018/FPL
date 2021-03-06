/* Author: Xinwei Zhang, Yipeng Zhou, Chih-Hung Lu, Dongdong She */
/* Ocamlyacc parser for Fpl */

%{
open Ast
%}

%token SEMI LPAREN RPAREN LBRACE RBRACE COMMA 
%token PLUS MINUS TIMES DIVIDE ASSIGN NOT
%token DOT
%token EQ NEQ LT LEQ GT GEQ TRUE FALSE AND OR
%token RETURN IF ELSE FOR WHILE INT BOOL VOID FLOAT CHAR STRING STRUCT 
%token WALL WALLCONSTRUCT BED BEDCONSTRUCT DESK DESKCONSTRUCT DOOR DOORCONSTRUCT 
%token WINDOW WINDOWCONSTRUCT RECTANGLE RECTANGLECONSTRUCT CIRCLE CIRCLECONSTRUCT 
%token <int> LITERAL
%token <float> FLOAT_LITERAL
%token <string> ID
%token <char> CHAR_LITERAL
%token <string> STRING_LITERAL
%token <string> STRUCT_ID
%token EOF

%nonassoc NOELSE
%nonassoc ELSE
%right ASSIGN
%left WALL 
%left BED 
%left DESK 
%left DOOR 
%left WINDOW 
%left RECTANGLE 
%left CIRCLE 
%left OR
%left AND
%left EQ NEQ
%left LT GT LEQ GEQ
%left PLUS MINUS
%left TIMES DIVIDE
%right NOT NEG

%start program
%type <Ast.program> program

%%

program:
  decls EOF { $1 }

decls:
   /* nothing */ { {globals=[]; functions=[]; structs=[]} }
 | decls vdecl { {globals = ($2 :: $1.globals); functions = $1.functions; structs = $1.structs} }
 | decls fdecl { {globals = $1.globals; functions = ($2 :: $1.functions); structs = $1.structs} }
 | decls struct_decl { {globals = $1.globals; functions = $1.functions; structs = ($2 :: $1.structs)} }

fdecl:
   typ ID LPAREN formals_opt RPAREN LBRACE vdecl_list stmt_list RBRACE
     { { typ = $1;
	 fname = $2;
	 formals = $4;
	 locals = List.rev $7;
	 body = List.rev $8 } }

formals_opt:
    /* nothing */ { [] }
  | formal_list   { List.rev $1 }

formal_list:
    typ ID                   { [($1,$2)] }
  | formal_list COMMA typ ID { ($3,$4) :: $1 }

struct_decl:
    STRUCT STRUCT_ID  LBRACE vdecl_list RBRACE SEMI
    { { members = $4;
        struct_name = $2; } }

typ:
    INT { Int }
  | BOOL { Bool }
  | VOID { Void }
  | FLOAT { Float }
  | CHAR { Char }
  | STRING { String }
  | WALL { Wall }
  | BED { Bed }
  | DESK { Desk }
  | DOOR { Door }
  | WINDOW { Window }
  | RECTANGLE { Rectangle }
  | CIRCLE { Circle }
  | STRUCT_ID { Struct($1) }

vdecl_list:
    /* nothing */    { [] }
  | vdecl_list vdecl { $2 :: $1 }

vdecl:
   typ ID SEMI { ($1, $2) }

stmt_list:
    /* nothing */  { [] }
  | stmt_list stmt { $2 :: $1 }

stmt:
    expr SEMI { Expr $1 }
  | RETURN SEMI { Return Noexpr }
  | RETURN expr SEMI { Return $2 }
  | LBRACE stmt_list RBRACE { Block(List.rev $2) }
  | IF LPAREN expr RPAREN stmt %prec NOELSE { If($3, $5, Block([])) }
  | IF LPAREN expr RPAREN stmt ELSE stmt    { If($3, $5, $7) }
  | FOR LPAREN expr_opt SEMI expr SEMI expr_opt RPAREN stmt
     { For($3, $5, $7, $9) }
  | WHILE LPAREN expr RPAREN stmt { While($3, $5) }

expr_opt:
    /* nothing */ { Noexpr }
  | expr          { $1 }

expr:
    LITERAL          { Literal($1) }
  | FLOAT_LITERAL    { FLiteral($1) }
  | CHAR_LITERAL     { CharLit($1) }
  | STRING_LITERAL   { StringLit($1) }
  | TRUE             { BoolLit(true) }
  | FALSE            { BoolLit(false) }
  | ID               { Id($1) }
  | ID ASSIGN WALL LPAREN actuals_opt RPAREN {WallConstruct($1, $5)}
  | ID ASSIGN BED LPAREN actuals_opt RPAREN {BedConstruct($1, $5)}
  | ID ASSIGN DESK LPAREN actuals_opt RPAREN {DeskConstruct($1, $5)}
  | ID ASSIGN DOOR LPAREN actuals_opt RPAREN {DoorConstruct($1, $5)}
  | ID ASSIGN WINDOW LPAREN actuals_opt RPAREN {WindowConstruct($1, $5)}
  | ID ASSIGN RECTANGLE LPAREN actuals_opt RPAREN {RectangleConstruct($1, $5)}
  | ID ASSIGN CIRCLE LPAREN actuals_opt RPAREN {CircleConstruct($1, $5)}
  | ID DOT ID ASSIGN WALL LPAREN actuals_opt RPAREN {WallStructConstruct($1, $3, $7)}
  | ID DOT ID ASSIGN BED LPAREN actuals_opt RPAREN {BedStructConstruct($1, $3, $7)}
  | ID DOT ID ASSIGN DESK LPAREN actuals_opt RPAREN {DeskStructConstruct($1, $3, $7)}
  | ID DOT ID ASSIGN DOOR LPAREN actuals_opt RPAREN {DoorStructConstruct($1, $3, $7)}
  | ID DOT ID ASSIGN WINDOW LPAREN actuals_opt RPAREN {WindowStructConstruct($1, $3, $7)}
  | ID DOT ID ASSIGN RECTANGLE LPAREN actuals_opt RPAREN {RectangleStructConstruct($1, $3, $7)}
  | ID DOT ID ASSIGN CIRCLE LPAREN actuals_opt RPAREN {CircleStructConstruct($1, $3, $7)}
  | expr PLUS   expr { Binop($1, Add,   $3) }
  | expr MINUS  expr { Binop($1, Sub,   $3) }
  | expr TIMES  expr { Binop($1, Mult,  $3) }
  | expr DIVIDE expr { Binop($1, Div,   $3) }
  | expr EQ     expr { Binop($1, Equal, $3) }
  | expr NEQ    expr { Binop($1, Neq,   $3) }
  | expr LT     expr { Binop($1, Less,  $3) }
  | expr LEQ    expr { Binop($1, Leq,   $3) }
  | expr GT     expr { Binop($1, Greater, $3) }
  | expr GEQ    expr { Binop($1, Geq,   $3) }
  | expr AND    expr { Binop($1, And,   $3) }
  | expr OR     expr { Binop($1, Or,    $3) }
  | MINUS expr %prec NEG { Unop(Neg, $2) }
  | NOT expr         { Unop(Not, $2) }
  | ID ASSIGN expr   { Assign($1, $3) }
  | ID LPAREN actuals_opt RPAREN { Call($1, $3) }
  | LPAREN expr RPAREN { $2 }

actuals_opt:
    /* nothing */ { [] }
  | actuals_list  { List.rev $1 }

actuals_list:
    expr                    { [$1] }
  | actuals_list COMMA expr { $3 :: $1 }
