(*  Title:      HOL/Library/Old_SMT/old_smt_real.ML
    Author:     Sascha Boehme, TU Muenchen

SMT setup for reals.
*)

structure Old_SMT_Real: sig end =
struct


(* SMT-LIB logic *)

fun smtlib_logic ts =
  if exists (Term.exists_type (Term.exists_subtype (equal @{typ real}))) ts
  then SOME "AUFLIRA"
  else NONE


(* SMT-LIB and Z3 built-ins *)

local
  fun real_num _ i = SOME (string_of_int i ^ ".0")

  fun is_linear [t] = Old_SMT_Utils.is_number t
    | is_linear [t, u] = Old_SMT_Utils.is_number t orelse Old_SMT_Utils.is_number u
    | is_linear _ = false

  fun mk_times ts = Term.list_comb (@{const times (real)}, ts)

  fun times _ _ ts = if is_linear ts then SOME ("*", 2, ts, mk_times) else NONE
in

val setup_builtins =
  Old_SMT_Builtin.add_builtin_typ Old_SMTLIB_Interface.smtlibC
    (@{typ real}, K (SOME "Real"), real_num) #>
  fold (Old_SMT_Builtin.add_builtin_fun' Old_SMTLIB_Interface.smtlibC) [
    (@{const less (real)}, "<"),
    (@{const less_eq (real)}, "<="),
    (@{const uminus (real)}, "~"),
    (@{const plus (real)}, "+"),
    (@{const minus (real)}, "-") ] #>
  Old_SMT_Builtin.add_builtin_fun Old_SMTLIB_Interface.smtlibC
    (Term.dest_Const @{const times (real)}, times) #>
  Old_SMT_Builtin.add_builtin_fun' Old_Z3_Interface.smtlib_z3C
    (@{const times (real)}, "*") #>
  Old_SMT_Builtin.add_builtin_fun' Old_Z3_Interface.smtlib_z3C
    (@{const divide (real)}, "/")

end


(* Z3 constructors *)

local
  fun z3_mk_builtin_typ (Old_Z3_Interface.Sym ("Real", _)) = SOME @{typ real}
    | z3_mk_builtin_typ (Old_Z3_Interface.Sym ("real", _)) = SOME @{typ real}
        (*FIXME: delete*)
    | z3_mk_builtin_typ _ = NONE

  fun z3_mk_builtin_num _ i T =
    if T = @{typ real} then SOME (Numeral.mk_cnumber @{ctyp real} i)
    else NONE

  fun mk_nary _ cu [] = cu
    | mk_nary ct _ cts = uncurry (fold_rev (Thm.mk_binop ct)) (split_last cts)

  val mk_uminus = Thm.apply (Thm.cterm_of @{context} @{const uminus (real)})
  val add = Thm.cterm_of @{context} @{const plus (real)}
  val real0 = Numeral.mk_cnumber @{ctyp real} 0
  val mk_sub = Thm.mk_binop (Thm.cterm_of @{context} @{const minus (real)})
  val mk_mul = Thm.mk_binop (Thm.cterm_of @{context} @{const times (real)})
  val mk_div = Thm.mk_binop (Thm.cterm_of @{context} @{const divide (real)})
  val mk_lt = Thm.mk_binop (Thm.cterm_of @{context} @{const less (real)})
  val mk_le = Thm.mk_binop (Thm.cterm_of @{context} @{const less_eq (real)})

  fun z3_mk_builtin_fun (Old_Z3_Interface.Sym ("-", _)) [ct] = SOME (mk_uminus ct)
    | z3_mk_builtin_fun (Old_Z3_Interface.Sym ("+", _)) cts =
        SOME (mk_nary add real0 cts)
    | z3_mk_builtin_fun (Old_Z3_Interface.Sym ("-", _)) [ct, cu] =
        SOME (mk_sub ct cu)
    | z3_mk_builtin_fun (Old_Z3_Interface.Sym ("*", _)) [ct, cu] =
        SOME (mk_mul ct cu)
    | z3_mk_builtin_fun (Old_Z3_Interface.Sym ("/", _)) [ct, cu] =
        SOME (mk_div ct cu)
    | z3_mk_builtin_fun (Old_Z3_Interface.Sym ("<", _)) [ct, cu] =
        SOME (mk_lt ct cu)
    | z3_mk_builtin_fun (Old_Z3_Interface.Sym ("<=", _)) [ct, cu] =
        SOME (mk_le ct cu)
    | z3_mk_builtin_fun (Old_Z3_Interface.Sym (">", _)) [ct, cu] =
        SOME (mk_lt cu ct)
    | z3_mk_builtin_fun (Old_Z3_Interface.Sym (">=", _)) [ct, cu] =
        SOME (mk_le cu ct)
    | z3_mk_builtin_fun _ _ = NONE
in

val z3_mk_builtins = {
  mk_builtin_typ = z3_mk_builtin_typ,
  mk_builtin_num = z3_mk_builtin_num,
  mk_builtin_fun = (fn _ => fn sym => fn cts =>
    (case try (Thm.typ_of_cterm o hd) cts of
      SOME @{typ real} => z3_mk_builtin_fun sym cts
    | _ => NONE)) }

end


(* Z3 proof reconstruction *)

val real_rules = @{lemma
  "0 + (x::real) = x"
  "x + 0 = x"
  "0 * x = 0"
  "1 * x = x"
  "x + y = y + x"
  by auto}

val real_linarith_proc =
  Simplifier.make_simproc @{context} "fast_real_arith"
   {lhss = [@{term "(m::real) < n"}, @{term "(m::real) \<le> n"}, @{term "(m::real) = n"}],
    proc = K Lin_Arith.simproc, identifier = []}


(* setup *)

val _ =
  Theory.setup
   (Context.theory_map (
      Old_SMTLIB_Interface.add_logic (10, smtlib_logic) #>
      setup_builtins #>
      Old_Z3_Interface.add_mk_builtins z3_mk_builtins #>
      fold Old_Z3_Proof_Reconstruction.add_z3_rule real_rules #>
      Old_Z3_Proof_Tools.add_simproc real_linarith_proc))

end
