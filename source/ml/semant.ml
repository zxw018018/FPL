(* Author: Yipeng Zhou, Xinwei Zhang, Chih-Hung Lu *)
(* Semantic checking for the Fpl compiler *)

open Ast

module StringMap = Map.Make(String)

(* Semantic checking of a program. Returns void if successful,
   throws an exception if something is wrong.

   Check each global variable, then check each function *)

let check program =

  (* Raise an exception if the given list has a duplicate *)
  let report_duplicate exceptf list =
    let rec helper = function
	n1 :: n2 :: _ when n1 = n2 -> raise (Failure (exceptf n1))
      | _ :: t -> helper t
      | [] -> ()
    in helper (List.sort compare list)
  in

  (* Raise an exception if a given binding is to a void type *)
  let check_not_void exceptf = function
      (Void, n) -> raise (Failure (exceptf n))
    | _ -> ()
  in
  
  (* Raise an exception of the given rvalue type cannot be assigned to
     the given lvalue type *)
  let check_assign lvaluet rvaluet err =
     if (lvaluet=Int) then lvaluet
     else if (Pervasives.(=) lvaluet rvaluet) then lvaluet else raise err 
  in
   
  (**** Checking Global Variables ****)

  List.iter (check_not_void (fun n -> "illegal void global " ^ n)) program.globals;
   
  report_duplicate (fun n -> "duplicate global " ^ n) (List.map snd program.globals);
  (**** Checking structs ****)
  report_duplicate (fun n -> "duplicate struct " ^ n)
    (List.map (fun fd -> fd.struct_name) program.structs);
  (**** Checking Functions ****)

  if List.mem "print" (List.map (fun fd -> fd.fname) program.functions)
  then raise (Failure ("function print may not be defined")) else ();

  report_duplicate (fun n -> "duplicate function " ^ n)
    (List.map (fun fd -> fd.fname) program.functions);

  (* Function declaration for a named function *)
  let built_in_decls =  StringMap.add "render"
     { typ = Void; fname = "render"; formals = [];
       locals = []; body = [] } (StringMap.add "rotate"
     { typ = Void; fname = "rotate"; formals = [(Int, "x"); (Int, "y")];
       locals = []; body = [] } (StringMap.add "put"
     { typ = Void; fname = "put"; formals = [(Int, "x"); (Float, "y"); (Float, "z")];
       locals = []; body = [] } (StringMap.add "putc"
     { typ = Void; fname = "putc"; formals = [(Int, "x")];
       locals = []; body = [] }  (StringMap.add "print"
     { typ = Void; fname = "print"; formals = [(Int, "x")];
       locals = []; body = [] } (StringMap.add "printS"
     { typ = Void; fname = "printS"; formals = [(String, "x")];
       locals = []; body = [] } (StringMap.add "printFloat"
     { typ = Void; fname = "printFloat"; formals = [(Float, "x")];
       locals = []; body = [] } (StringMap.add "printChar"
     { typ = Void; fname = "printChar"; formals = [(Char, "x")];
       locals = []; body = [] } (StringMap.add "printb"
     { typ = Void; fname = "printb"; formals = [(Bool, "x")];
       locals = []; body = [] } (StringMap.add "printbig"
     { typ = Void; fname = "printbig"; formals = [(Int, "x")];
       locals = []; body = [] } (StringMap.add "drawLine"
     { typ = Void; fname = "drawLine"; formals = [(Int, "x")];
       locals = []; body = [] }  (StringMap.singleton "drawRec"
     { typ = Void; fname = "drawRec"; formals = [(Int, "x")];
     locals = []; body = [] } )))))))))))
   in
     
  let function_decls = List.fold_left (fun m fd -> StringMap.add fd.fname fd m)
                         built_in_decls program.functions
  in

  let function_decl s = try StringMap.find s function_decls
       with Not_found -> raise (Failure ("unrecognized function " ^ s))
  in

  let _ = function_decl "main" in (* Ensure "main" is defined *)

  let check_function func=

    List.iter (check_not_void (fun n -> "illegal void formal " ^ n ^
      " in " ^ func.fname)) func.formals;

    report_duplicate (fun n -> "duplicate formal " ^ n ^ " in " ^ func.fname)
      (List.map snd func.formals);

    List.iter (check_not_void (fun n -> "illegal void local " ^ n ^
      " in " ^ func.fname)) func.locals;

    report_duplicate (fun n -> "duplicate local " ^ n ^ " in " ^ func.fname)
      (List.map snd func.locals);
    (* Type of each variable (global, formal, or local *)
    let symbols = List.fold_left (fun m (t, n) -> StringMap.add n t m)
	     StringMap.empty (program.globals @ func.formals @ func.locals)
    in
    let struct_decls = List.fold_left (fun m sd -> StringMap.add sd.struct_name sd m)
                        StringMap.empty program.structs
    in
    let struct_decl s = try StringMap.find s struct_decls
      with Not_found -> raise (Failure ("unrecognized struct " ^ s))
    in

    let type_of_identifier s =
      try StringMap.find s symbols
      with Not_found -> raise (Failure ("undeclared identifier " ^ s))
    in
    let type_of_identifier_s s k t=
      try StringMap.find s k
      with Not_found -> raise (Failure ("undeclared identifier " ^ t ^ "." ^s))
    in

(* check if given type is an int or float *)
    let isNumType t = if (t = Int || t = Float) then true else false in
    
    (* Return the type of an expression or throw an exception *)
    let rec expr = function
	    Literal _ -> Int
      | BoolLit _ -> Bool
      | FLiteral _ -> Float
      | CharLit _ -> Char
      | StringLit _ -> String
      | Id s -> type_of_identifier s
      | WallStructConstruct(structName, memberName, _) -> 
        let sd = struct_decl (string_of_typ (type_of_identifier structName)) in
        let ss = List.fold_left (fun m (t, n) -> StringMap.add n t m)
          StringMap.empty (sd.members)
        in
        let name =  type_of_identifier_s memberName ss structName in
        if(name=Wall) then Wall
          else raise(Failure ("Excepted type wall for "^ structName ^"."^ memberName ^", got "^string_of_typ name))
      | BedStructConstruct(structName, memberName, _) -> 
        let sd = struct_decl (string_of_typ (type_of_identifier structName)) in
        let ss = List.fold_left (fun m (t, n) -> StringMap.add n t m)
          StringMap.empty (sd.members)
        in
        let name =  type_of_identifier_s memberName ss structName in
        if(name=Bed) then Bed
          else raise(Failure ("Excepted type bed for "^ structName ^"."^ memberName ^", got "^string_of_typ name))
      | DeskStructConstruct(structName, memberName, _) -> 
        let sd = struct_decl (string_of_typ (type_of_identifier structName)) in
        let ss = List.fold_left (fun m (t, n) -> StringMap.add n t m)
          StringMap.empty (sd.members)
        in
        let name =  type_of_identifier_s memberName ss structName in
        if(name=Desk) then Desk
          else raise(Failure ("Excepted type desk for "^ structName ^"."^ memberName ^", got "^string_of_typ name))
      | DoorStructConstruct(structName, memberName, _) -> 
        let sd = struct_decl (string_of_typ (type_of_identifier structName)) in
        let ss = List.fold_left (fun m (t, n) -> StringMap.add n t m)
          StringMap.empty (sd.members)
        in
        let name =  type_of_identifier_s memberName ss structName in
        if(name=Door) then Door
          else raise(Failure ("Excepted type door for "^ structName ^"."^ memberName ^", got "^string_of_typ name))
      | WindowStructConstruct(structName, memberName, _) -> 
        let sd = struct_decl (string_of_typ (type_of_identifier structName)) in
        let ss = List.fold_left (fun m (t, n) -> StringMap.add n t m)
          StringMap.empty (sd.members)
        in
        let name =  type_of_identifier_s memberName ss structName in
        if(name=Window) then Window
          else raise(Failure ("Excepted type window for "^ structName ^"."^ memberName ^", got "^string_of_typ name))
      | RectangleStructConstruct(structName, memberName, _) -> 
        let sd = struct_decl (string_of_typ (type_of_identifier structName)) in
        let ss = List.fold_left (fun m (t, n) -> StringMap.add n t m)
          StringMap.empty (sd.members)
        in
        let name =  type_of_identifier_s memberName ss structName in
        if(name=Rectangle) then Rectangle
          else raise(Failure ("Excepted type rectangle for "^ structName ^"."^ memberName ^", got "^string_of_typ name))
      | CircleStructConstruct(structName, memberName, _) -> 
        let sd = struct_decl (string_of_typ (type_of_identifier structName)) in
        let ss = List.fold_left (fun m (t, n) -> StringMap.add n t m)
          StringMap.empty (sd.members)
        in
        let name =  type_of_identifier_s memberName ss structName in
        if(name=Circle) then Circle
          else raise(Failure ("Excepted type circle for "^ structName ^"."^ memberName ^", got "^string_of_typ name))
      | WallConstruct(n, actuals) -> let name = type_of_identifier n and f = List.map expr actuals in
      if (List.length f==2) then 
        if(List.for_all(isNumType) f)then
          if(name=Wall) then Wall
          else raise(Failure ("wrong type " ^ string_of_typ name ^" for wall"))
        else raise (Failure ("expected numeric input for wall"))
      else raise(Failure("Wrong number of parameters for wall"))

      | BedConstruct(n, actuals) -> let name = type_of_identifier n and f = List.map expr actuals in
      if (List.length f==2) then
        if (List.for_all(isNumType) f)then
          if(name=Bed) then Bed
          else raise(Failure ("wrong type " ^ string_of_typ name ^" for bed"))
        else raise (Failure ("expected numeric input for bed"))
      else raise(Failure("Wrong number of parameters for bed"))
      
      | DeskConstruct(n, actuals) -> let name = type_of_identifier n and f = List.map expr actuals in
      if (List.length f==2) then
        if (List.for_all(isNumType) f) then 
          if(name=Desk) then Desk
          else raise(Failure ("wrong type " ^ string_of_typ name ^" for desk"))
        else raise (Failure ("expected numeric input for desk"))
      else raise(Failure("Wrong number of parameters for desk"))

      | DoorConstruct(n, actuals) -> let name = type_of_identifier n and f = List.map expr actuals in
      if (List.length f==2) then
        if (List.for_all(isNumType) f) then
          if(name=Door) then Door
          else raise(Failure ("wrong type " ^ string_of_typ name ^" for door"))
        else raise (Failure ("expected numeric input for door"))
      else raise(Failure("Wrong number of parameters for door"))

      | WindowConstruct(n, actuals) -> let name = type_of_identifier n and f = List.map expr actuals in
      if (List.length f==2) then
        if (List.for_all(isNumType) f) then
          if(name=Window) then Window
          else raise(Failure ("wrong type " ^ string_of_typ name ^" for window"))
        else raise (Failure ("expected numeric input for window"))
      else raise(Failure("Wrong number of parameters for window"))

      | RectangleConstruct(n, actuals) -> let name = type_of_identifier n and f = List.map expr actuals in
      if (List.length f==2) then
        if (List.for_all(isNumType) f) then
          if(name=Rectangle) then Rectangle
          else raise(Failure ("wrong type " ^ string_of_typ name ^" for rectangle"))
        else raise (Failure ("expected numeric input for rectangle"))
      else raise(Failure("Wrong number of parameters for rectangle"))

      | CircleConstruct(n, actuals) -> let name = type_of_identifier n and f = List.map expr actuals in
      if (List.length f==3) then
        if (List.for_all(isNumType) f)then
          if(name=Circle) then Circle
          else raise(Failure ("wrong type " ^ string_of_typ name ^" for circle"))
        else raise (Failure ("expected numeric input for circle"))
      else raise(Failure("Wrong number of parameters for circle"))

      | Binop(e1, op, e2) as e -> let t1 = expr e1 and t2 = expr e2 in
	(match op with
          Add | Sub | Mult | Div when t1 = Int && t2 = Int -> Int
          | Add | Sub | Mult | Div when t1 = Int && t2 = Float -> Float
          | Add | Sub | Mult | Div when t1 = Float && t2 = Int -> Float
          | Add | Sub | Mult | Div when t1 = Float && t2 = Float -> Float
	        | Equal | Neq when t1 = t2 -> Bool
          | Less | Leq | Greater | Geq when t1 = Int && t2 = Int -> Bool
          | Less | Leq | Greater | Geq when t1 = Float && t2 = Float -> Bool
          | Less | Leq | Greater | Geq when t1 = Int && t2 = Float -> Bool
          | Less | Leq | Greater | Geq when t1 = Float && t2 = Int -> Bool
	        | And | Or when t1 = Bool && t2 = Bool -> Bool
           | _ -> raise (Failure ("illegal binary operator " ^
              string_of_typ t1 ^ " " ^ string_of_op op ^ " " ^
              string_of_typ t2 ^ " in " ^ string_of_expr e))
        )
      | Unop(op, e) as ex -> let t = expr e in
	 (match op with
     Neg when t = Int -> Int
   | Neg when t = Float -> Float
	 | Not when t = Bool -> Bool
         | _ -> raise (Failure ("illegal unary operator " ^ string_of_uop op ^
	  		   string_of_typ t ^ " in " ^ string_of_expr ex)))
      | Noexpr -> Void
      | Assign(var, e) as ex -> let lt = type_of_identifier var
                                and rt = expr e in
        check_assign lt rt (Failure ("illegal assignment " ^ string_of_typ lt ^
				     " = " ^ string_of_typ rt ^ " in " ^ 
				     string_of_expr ex))
      | Call(fname, actuals) as call -> let fd = function_decl fname in
         if List.length actuals != List.length fd.formals then
           raise (Failure ("expecting " ^ string_of_int
             (List.length fd.formals) ^ " arguments in " ^ string_of_expr call))
         else
           List.iter2 (fun (ft, _) e -> let et = expr e in
              ignore (check_assign ft et
                (Failure ("illegal actual argument found " ^ string_of_typ et ^
                " expected " ^ string_of_typ ft ^ " in " ^ string_of_expr e))))
             fd.formals actuals;
           fd.typ
      (*| _ -> raise (Failure ("illegal expression"))*)
    in

    let check_bool_expr e = if expr e != Bool
     then raise (Failure ("expected Boolean expression in " ^ string_of_expr e))
     else () in

    (* Verify a statement or throw an exception *)
    let rec stmt = function
	Block sl -> let rec check_block = function
           [Return _ as s] -> stmt s
         | Return _ :: _ -> raise (Failure "nothing may follow a return")
         | Block sl :: ss -> check_block (sl @ ss)
         | s :: ss -> stmt s ; check_block ss
         | [] -> ()
        in check_block sl
      | Expr e -> ignore (expr e)
      | Return e -> let t = expr e in if t = func.typ then () else
         raise (Failure ("return gives " ^ string_of_typ t ^ " expected " ^
                         string_of_typ func.typ ^ " in " ^ string_of_expr e))
           
      | If(p, b1, b2) -> check_bool_expr p; stmt b1; stmt b2
      | For(e1, e2, e3, st) -> ignore (expr e1); check_bool_expr e2;
                               ignore (expr e3); stmt st
      | While(p, s) -> check_bool_expr p; stmt s
    in

    stmt (Block func.body)
   
  in
  List.iter check_function program.functions
