(*  Title:      HOL/Tools/ATP/atp_systems.ML
    Author:     Fabian Immler, TU Muenchen
    Author:     Jasmin Blanchette, TU Muenchen

Setup for supported ATPs.
*)

signature ATP_SYSTEMS =
sig
  type term_order = ATP_Problem.term_order
  type atp_format = ATP_Problem.atp_format
  type atp_formula_role = ATP_Problem.atp_formula_role
  type atp_failure = ATP_Proof.atp_failure

  type slice_spec = (int * string) * atp_format * string * string * bool
  type atp_config =
    {exec : bool -> string list * string list,
     arguments : Proof.context -> bool -> string -> Time.time -> string ->
       term_order * (unit -> (string * int) list) * (unit -> (string * real) list) -> string,
     proof_delims : (string * string) list,
     known_failures : (atp_failure * string) list,
     prem_role : atp_formula_role,
     best_slices : Proof.context -> (real * (slice_spec * string)) list,
     best_max_mono_iters : int,
     best_max_new_mono_instances : int}

  val default_max_mono_iters : int
  val default_max_new_mono_instances : int
  val force_sos : bool Config.T
  val term_order : string Config.T
  val e_smartN : string
  val e_autoN : string
  val e_fun_weightN : string
  val e_sym_offset_weightN : string
  val e_selection_heuristic : string Config.T
  val e_default_fun_weight : real Config.T
  val e_fun_weight_base : real Config.T
  val e_fun_weight_span : real Config.T
  val e_default_sym_offs_weight : real Config.T
  val e_sym_offs_weight_base : real Config.T
  val e_sym_offs_weight_span : real Config.T
  val spass_H1SOS : string
  val spass_H2 : string
  val spass_H2LR0LT0 : string
  val spass_H2NuVS0 : string
  val spass_H2NuVS0Red2 : string
  val spass_H2SOS : string
  val spass_extra_options : string Config.T
  val remote_atp : string -> string -> string list -> (string * string) list ->
    (atp_failure * string) list -> atp_formula_role -> (Proof.context -> slice_spec * string) ->
    string * (unit -> atp_config)
  val add_atp : string * (unit -> atp_config) -> theory -> theory
  val get_atp : theory -> string -> (unit -> atp_config)
  val supported_atps : theory -> string list
  val is_atp_installed : theory -> string -> bool
  val refresh_systems_on_tptp : unit -> unit
  val effective_term_order : Proof.context -> string -> term_order
end;

structure ATP_Systems : ATP_SYSTEMS =
struct

open ATP_Problem
open ATP_Proof
open ATP_Problem_Generate


(* ATP configuration *)

val default_max_mono_iters = 3 (* FUDGE *)
val default_max_new_mono_instances = 100 (* FUDGE *)

type slice_spec = (int * string) * atp_format * string * string * bool

type atp_config =
  {exec : bool -> string list * string list,
   arguments : Proof.context -> bool -> string -> Time.time -> string ->
     term_order * (unit -> (string * int) list) * (unit -> (string * real) list) -> string,
   proof_delims : (string * string) list,
   known_failures : (atp_failure * string) list,
   prem_role : atp_formula_role,
   best_slices : Proof.context -> (real * (slice_spec * string)) list,
   best_max_mono_iters : int,
   best_max_new_mono_instances : int}

(* "best_slices" must be found empirically, taking a wholistic approach since
   the ATPs are run in parallel. Each slice has the format

     (time_frac, ((max_facts, fact_filter), format, type_enc,
                  lam_trans, uncurried_aliases), extra)

   where

     time_frac = faction of the time available given to the slice (which should
       add up to 1.0)

     extra = extra information to the prover (e.g., SOS or no SOS).

   The last slice should be the most "normal" one, because it will get all the
   time available if the other slices fail early and also because it is used if
   slicing is disabled (e.g., by the minimizer). *)

val mepoN = "mepo"
val mashN = "mash"
val meshN = "mesh"

val tstp_proof_delims =
  [("% SZS output start CNFRefutation", "% SZS output end CNFRefutation"),
   ("% SZS output start Refutation", "% SZS output end Refutation"),
   ("% SZS output start Proof", "% SZS output end Proof")]

val known_perl_failures =
  [(CantConnect, "HTTP error"),
   (NoPerl, "env: perl"),
   (NoLibwwwPerl, "Can't locate HTTP")]

fun known_szs_failures wrap =
  [(Unprovable, wrap "CounterSatisfiable"),
   (Unprovable, wrap "Satisfiable"),
   (GaveUp, wrap "GaveUp"),
   (GaveUp, wrap "Unknown"),
   (GaveUp, wrap "Incomplete"),
   (ProofMissing, wrap "Theorem"),
   (ProofMissing, wrap "Unsatisfiable"),
   (TimedOut, wrap "Timeout"),
   (Inappropriate, wrap "Inappropriate"),
   (OutOfResources, wrap "ResourceOut"),
   (OutOfResources, wrap "MemoryOut"),
   (Interrupted, wrap "Forced"),
   (Interrupted, wrap "User")]

val known_szs_status_failures = known_szs_failures (prefix "SZS status ")
val known_says_failures = known_szs_failures (prefix " says ")

structure Data = Theory_Data
(
  type T = ((unit -> atp_config) * stamp) Symtab.table
  val empty = Symtab.empty
  val extend = I
  fun merge data : T =
    Symtab.merge (eq_snd (op =)) data
    handle Symtab.DUP name => error ("Duplicate ATP: " ^ quote name ^ ".")
)

fun to_secs min time = Int.max (min, (Time.toMilliseconds time + 999) div 1000)

val sosN = "sos"
val no_sosN = "no_sos"

val force_sos = Attrib.setup_config_bool @{binding atp_force_sos} (K false)

val smartN = "smart"
(* val kboN = "kbo" *)
val lpoN = "lpo"
val xweightsN = "_weights"
val xprecN = "_prec"
val xsimpN = "_simp" (* SPASS-specific *)

(* Possible values for "atp_term_order":
   "smart", "(kbo|lpo)(_weights)?(_prec|_simp)?" *)
val term_order =
  Attrib.setup_config_string @{binding atp_term_order} (K smartN)


(* agsyHOL *)

val agsyhol_thf0 = THF (Monomorphic, THF_Without_Choice)

val agsyhol_config : atp_config =
  {exec = K (["AGSYHOL_HOME"], ["agsyHOL"]),
   arguments = fn _ => fn _ => fn _ => fn timeout => fn file_name => fn _ =>
       "--proof --time-out " ^ string_of_int (to_secs 1 timeout) ^ " " ^
       file_name,
   proof_delims = tstp_proof_delims,
   known_failures = known_szs_status_failures,
   prem_role = Hypothesis,
   best_slices =
     (* FUDGE *)
     K [(1.0, (((60, ""), agsyhol_thf0, "mono_native_higher", keep_lamsN, false), ""))],
   best_max_mono_iters = default_max_mono_iters - 1 (* FUDGE *),
   best_max_new_mono_instances = default_max_new_mono_instances}

val agsyhol = (agsyholN, fn () => agsyhol_config)


(* Alt-Ergo *)

val alt_ergo_config : atp_config =
  {exec = K (["WHY3_HOME"], ["why3"]),
   arguments = fn _ => fn _ => fn _ => fn timeout => fn file_name => fn _ =>
       "--format tptp --prover 'Alt-Ergo,0.95.2,' --timelimit " ^
       string_of_int (to_secs 1 timeout) ^ " " ^ file_name,
   proof_delims = [],
   known_failures =
     [(ProofMissing, ": Valid"),
      (TimedOut, ": Timeout"),
      (GaveUp, ": Unknown")],
   prem_role = Hypothesis,
   best_slices = fn _ =>
     (* FUDGE *)
     [(1.0, (((100, ""), TFF Polymorphic, "poly_native", liftingN, false), ""))],
   best_max_mono_iters = default_max_mono_iters,
   best_max_new_mono_instances = default_max_new_mono_instances}

val alt_ergo = (alt_ergoN, fn () => alt_ergo_config)


(* E *)

fun is_e_at_least_1_8 () = string_ord (getenv "E_VERSION", "1.8") <> LESS

val e_smartN = "smart"
val e_autoN = "auto"
val e_fun_weightN = "fun_weight"
val e_sym_offset_weightN = "sym_offset_weight"

val e_selection_heuristic =
  Attrib.setup_config_string @{binding atp_e_selection_heuristic} (K e_smartN)
(* FUDGE *)
val e_default_fun_weight =
  Attrib.setup_config_real @{binding atp_e_default_fun_weight} (K 20.0)
val e_fun_weight_base =
  Attrib.setup_config_real @{binding atp_e_fun_weight_base} (K 0.0)
val e_fun_weight_span =
  Attrib.setup_config_real @{binding atp_e_fun_weight_span} (K 40.0)
val e_default_sym_offs_weight =
  Attrib.setup_config_real @{binding atp_e_default_sym_offs_weight} (K 1.0)
val e_sym_offs_weight_base =
  Attrib.setup_config_real @{binding atp_e_sym_offs_weight_base} (K ~20.0)
val e_sym_offs_weight_span =
  Attrib.setup_config_real @{binding atp_e_sym_offs_weight_span} (K 60.0)

fun e_selection_heuristic_case heuristic fw sow =
  if heuristic = e_fun_weightN then fw
  else if heuristic = e_sym_offset_weightN then sow
  else raise Fail ("unexpected " ^ quote heuristic)

fun scaled_e_selection_weight ctxt heuristic w =
  w * Config.get ctxt (e_selection_heuristic_case heuristic
                           e_fun_weight_span e_sym_offs_weight_span)
  + Config.get ctxt (e_selection_heuristic_case heuristic
                         e_fun_weight_base e_sym_offs_weight_base)
  |> Real.ceil |> signed_string_of_int

fun e_selection_weight_arguments ctxt heuristic sel_weights =
  if heuristic = e_fun_weightN orelse heuristic = e_sym_offset_weightN then
    (* supplied by Stephan Schulz *)
    "--split-clauses=4 --split-reuse-defs --simul-paramod --forward-context-sr \
    \--destructive-er-aggressive --destructive-er --presat-simplify \
    \--prefer-initial-clauses -winvfreqrank -c1 -Ginvfreqconjmax -F1 \
    \--delete-bad-limit=150000000 -WSelectMaxLComplexAvoidPosPred -H'(4*" ^
    e_selection_heuristic_case heuristic "FunWeight" "SymOffsetWeight" ^
    "(SimulateSOS," ^
    (e_selection_heuristic_case heuristic
         e_default_fun_weight e_default_sym_offs_weight
     |> Config.get ctxt |> Real.ceil |> signed_string_of_int) ^
    ",20,1.5,1.5,1" ^
    (sel_weights ()
     |> map (fn (s, w) => "," ^ s ^ ":" ^
                          scaled_e_selection_weight ctxt heuristic w)
     |> implode) ^
    "),3*ConjectureGeneralSymbolWeight(PreferNonGoals,200,100,200,50,50,1,100,\
    \1.5,1.5,1),1*Clauseweight(PreferProcessed,1,1,1),1*\
    \FIFOWeight(PreferProcessed))' "
  else
    "-xAuto "

val e_ord_weights =
  map (fn (s, w) => s ^ ":" ^ string_of_int w) #> space_implode ","
fun e_ord_precedence [_] = ""
  | e_ord_precedence info = info |> map fst |> space_implode "<"

fun e_term_order_info_arguments false false _ = ""
  | e_term_order_info_arguments gen_weights gen_prec ord_info =
    let val ord_info = ord_info () in
      (if gen_weights then "--order-weights='" ^ e_ord_weights ord_info ^ "' " else "") ^
      (if gen_prec then "--precedence='" ^ e_ord_precedence ord_info ^ "' " else "")
    end

val e_config : atp_config =
  {exec = fn full_proofs => (["E_HOME"],
     if full_proofs orelse not (is_e_at_least_1_8 ()) then ["eproof_ram", "eproof"]
     else ["eprover"]),
   arguments = fn ctxt => fn full_proofs => fn heuristic => fn timeout => fn file_name =>
     fn ({is_lpo, gen_weights, gen_prec, ...}, ord_info, sel_weights) =>
       (if is_e_at_least_1_8 () then "--auto-schedule " else "") ^
       "--tstp-in --tstp-out --silent " ^
       e_selection_weight_arguments ctxt heuristic sel_weights ^
       e_term_order_info_arguments gen_weights gen_prec ord_info ^
       "--term-ordering=" ^ (if is_lpo then "LPO4" else "KBO6") ^ " " ^
       "--cpu-limit=" ^ string_of_int (to_secs 2 timeout) ^
       (if full_proofs orelse not (is_e_at_least_1_8 ()) then
          " --output-level=5 --pcl-shell-level=" ^ (if full_proofs then "0" else "2")
        else
          " --proof-object=1") ^
       " " ^ file_name,
   proof_delims =
     [("# SZS output start CNFRefutation", "# SZS output end CNFRefutation")] @
     tstp_proof_delims,
   known_failures =
     [(TimedOut, "Failure: Resource limit exceeded (time)"),
      (TimedOut, "time limit exceeded")] @
     known_szs_status_failures,
   prem_role = Conjecture,
   best_slices = fn ctxt =>
     let val heuristic = Config.get ctxt e_selection_heuristic in
       (* FUDGE *)
       if heuristic = e_smartN then
         [(0.15, (((128, meshN), FOF, "mono_tags??", combsN, false), e_fun_weightN)),
          (0.15, (((128, mashN), FOF, "mono_guards??", combsN, false), e_sym_offset_weightN)),
          (0.15, (((91, mepoN), FOF, "mono_tags??", combsN, false), e_autoN)),
          (0.15, (((1000, meshN), FOF, "poly_guards??", combsN, false), e_sym_offset_weightN)),
          (0.15, (((256, mepoN), FOF, "mono_tags??", liftingN, false), e_fun_weightN)),
          (0.25, (((64, mashN), FOF, "mono_guards??", combsN, false), e_fun_weightN))]
       else
         [(1.0, (((500, ""), FOF, "mono_tags??", combsN, false), heuristic))]
     end,
   best_max_mono_iters = default_max_mono_iters,
   best_max_new_mono_instances = default_max_new_mono_instances}

val e = (eN, fn () => e_config)


(* E-MaLeS *)

val e_males_config : atp_config =
  {exec = K (["E_MALES_HOME"], ["emales.py"]),
   arguments = fn _ => fn _ => fn _ => fn timeout => fn file_name => fn _ =>
       "-t " ^ string_of_int (to_secs 1 timeout) ^ " -p " ^ file_name,
   proof_delims = tstp_proof_delims,
   known_failures = #known_failures e_config,
   prem_role = Conjecture,
   best_slices =
     (* FUDGE *)
     K [(0.25, (((500, meshN), FOF, "mono_guards??", combs_or_liftingN, false), "")),
        (0.25, (((150, meshN), FOF, "poly_tags??", combs_or_liftingN, false), "")),
        (0.25, (((50, meshN), FOF, "mono_tags??", combs_or_liftingN, false), "")),
        (0.25, (((1000, meshN), FOF, "poly_guards??", combsN, false), ""))],
   best_max_mono_iters = default_max_mono_iters,
   best_max_new_mono_instances = default_max_new_mono_instances}

val e_males = (e_malesN, fn () => e_males_config)


(* E-Par *)

val e_par_config : atp_config =
  {exec = K (["E_HOME"], ["runepar.pl"]),
   arguments = fn _ => fn _ => fn _ => fn timeout => fn file_name => fn _ =>
       string_of_int (to_secs 1 timeout) ^ " 1 " (* SInE *) ^ file_name ^
       " 2" (* proofs *),
   proof_delims = tstp_proof_delims,
   known_failures = #known_failures e_config,
   prem_role = Conjecture,
   best_slices = #best_slices e_males_config,
   best_max_mono_iters = default_max_mono_iters,
   best_max_new_mono_instances = default_max_new_mono_instances}

val e_par = (e_parN, fn () => e_par_config)


(* iProver *)

val iprover_config : atp_config =
  {exec = K (["IPROVER_HOME"], ["iprover"]),
   arguments = fn _ => fn _ => fn _ => fn timeout => fn file_name => fn _ =>
       "--clausifier \"$IPROVER_HOME\"/vclausify_rel --time_out_real " ^
       string_of_real (Time.toReal timeout) ^ " " ^ file_name,
   proof_delims = tstp_proof_delims,
   known_failures =
     [(ProofIncomplete, "% SZS output start CNFRefutation")] @
     known_szs_status_failures,
   prem_role = Hypothesis,
   best_slices =
     (* FUDGE *)
     K [(1.0, (((150, ""), FOF, "mono_guards??", liftingN, false), ""))],
   best_max_mono_iters = default_max_mono_iters,
   best_max_new_mono_instances = default_max_new_mono_instances}

val iprover = (iproverN, fn () => iprover_config)


(* iProver-Eq *)

val iprover_eq_config : atp_config =
  {exec = K (["IPROVER_EQ_HOME"], ["iprover-eq"]),
   arguments = #arguments iprover_config,
   proof_delims = #proof_delims iprover_config,
   known_failures = #known_failures iprover_config,
   prem_role = #prem_role iprover_config,
   best_slices = #best_slices iprover_config,
   best_max_mono_iters = #best_max_mono_iters iprover_config,
   best_max_new_mono_instances = #best_max_new_mono_instances iprover_config}

val iprover_eq = (iprover_eqN, fn () => iprover_eq_config)


(* LEO-II *)

val leo2_thf0 = THF (Monomorphic, THF_Without_Choice)

val leo2_config : atp_config =
  {exec = K (["LEO2_HOME"], ["leo.opt", "leo"]),
   arguments = fn _ => fn full_proofs => fn _ => fn timeout => fn file_name => fn _ =>
     "--foatp e --atp e=\"$E_HOME\"/eprover \
     \--atp epclextract=\"$E_HOME\"/epclextract \
     \--proofoutput 1 --timeout " ^ string_of_int (to_secs 1 timeout) ^ " " ^
     (if full_proofs then "--notReplLeibnizEQ --notReplAndrewsEQ --notUseExtCnfCmbd " else "") ^
     file_name,
   proof_delims = tstp_proof_delims,
   known_failures =
     [(TimedOut, "CPU time limit exceeded, terminating"),
      (GaveUp, "No.of.Axioms")] @
     known_szs_status_failures,
   prem_role = Hypothesis,
   best_slices =
     (* FUDGE *)
     K [(1.0, (((40, ""), leo2_thf0, "mono_native_higher", keep_lamsN, false), ""))],
   best_max_mono_iters = default_max_mono_iters - 1 (* FUDGE *),
   best_max_new_mono_instances = default_max_new_mono_instances}

val leo2 = (leo2N, fn () => leo2_config)


(* Satallax *)

(* Choice is disabled until there is proper reconstruction for it. *)
val satallax_thf0 = THF (Monomorphic, THF_Without_Choice)

val satallax_config : atp_config =
  {exec = K (["SATALLAX_HOME"], ["satallax.opt", "satallax"]),
   arguments = fn _ => fn _ => fn _ => fn timeout => fn file_name => fn _ =>
       "-p tstp -t " ^ string_of_int (to_secs 1 timeout) ^ " " ^ file_name,
   proof_delims =
     [("% SZS output start Proof", "% SZS output end Proof")],
   known_failures = known_szs_status_failures,
   prem_role = Hypothesis,
   best_slices =
     (* FUDGE *)
     K [(1.0, (((60, ""), satallax_thf0, "mono_native_higher", keep_lamsN, false), ""))],
   best_max_mono_iters = default_max_mono_iters - 1 (* FUDGE *),
   best_max_new_mono_instances = default_max_new_mono_instances}

val satallax = (satallaxN, fn () => satallax_config)


(* SPASS *)

val spass_H1SOS = "-Heuristic=1 -SOS"
val spass_H2 = "-Heuristic=2"
val spass_H2LR0LT0 = "-Heuristic=2 -LR=0 -LT=0"
val spass_H2NuVS0 = "-Heuristic=2 -RNuV=1 -Sorts=0"
val spass_H2NuVS0Red2 = "-Heuristic=2 -RNuV=1 -Sorts=0 -RFRew=2 -RBRew=2 -RTaut=2"
val spass_H2SOS = "-Heuristic=2 -SOS"

val spass_extra_options =
  Attrib.setup_config_string @{binding atp_spass_extra_options} (K "")

(* FIXME: Make "SPASS_NEW_HOME" legacy. *)
val spass_config : atp_config =
  {exec = K (["SPASS_NEW_HOME", "SPASS_HOME"], ["SPASS"]),
   arguments = fn _ => fn full_proofs => fn extra_options => fn timeout =>
       fn file_name => fn _ =>
       "-Isabelle=1 " ^ (if full_proofs then "-CNFRenaming=0 -Splits=0 " else "") ^
       "-TimeLimit=" ^ string_of_int (to_secs 1 timeout) ^ " " ^ file_name
       |> extra_options <> "" ? prefix (extra_options ^ " "),
   proof_delims = [("Here is a proof", "Formulae used in the proof")],
   known_failures =
     [(GaveUp, "SPASS beiseite: Completion found"),
      (TimedOut, "SPASS beiseite: Ran out of time"),
      (OutOfResources, "SPASS beiseite: Maximal number of loops exceeded"),
      (MalformedInput, "Undefined symbol"),
      (MalformedInput, "Free Variable"),
      (Unprovable, "No formulae and clauses found in input file"),
      (InternalError, "Please report this error")] @
      known_perl_failures,
   prem_role = Conjecture,
   best_slices = fn ctxt =>
     (* FUDGE *)
     [(0.1667, (((150, meshN), DFG Monomorphic, "mono_native", combsN, true), "")),
      (0.1667, (((500, meshN), DFG Monomorphic, "mono_native", liftingN, true), spass_H2SOS)),
      (0.1666, (((50, meshN), DFG Monomorphic,  "mono_native", liftingN, true), spass_H2LR0LT0)),
      (0.1000, (((250, meshN), DFG Monomorphic, "mono_native", combsN, true), spass_H2NuVS0)),
      (0.1000, (((1000, mepoN), DFG Monomorphic, "mono_native", liftingN, true), spass_H1SOS)),
      (0.1000, (((150, meshN), DFG Monomorphic, "poly_guards??", liftingN, false), spass_H2NuVS0Red2)),
      (0.1000, (((300, meshN), DFG Monomorphic, "mono_native", combsN, true), spass_H2SOS)),
      (0.1000, (((100, meshN), DFG Monomorphic, "mono_native", combs_and_liftingN, true), spass_H2))]
     |> (case Config.get ctxt spass_extra_options of
           "" => I
         | opts => map (apsnd (apsnd (K opts)))),
   best_max_mono_iters = default_max_mono_iters,
   best_max_new_mono_instances = default_max_new_mono_instances}

val spass = (spassN, fn () => spass_config)


(* Vampire *)

(* Vampire 1.8 has TFF0 support, but the support was buggy until revision
   1435 (or shortly before). *)
fun is_vampire_at_least_1_8 () = string_ord (getenv "VAMPIRE_VERSION", "1.8") <> LESS
fun is_vampire_beyond_1_8 () = string_ord (getenv "VAMPIRE_VERSION", "1.8") = GREATER

val vampire_tff0 = TFF Monomorphic

val vampire_basic_options = "--proof tptp --output_axiom_names on --mode casc"

(* cf. p. 20 of http://www.complang.tuwien.ac.at/lkovacs/Cade23_Tutorial_Slides/Session2_Slides.pdf *)
val vampire_full_proof_options =
  " --forced_options splitting=off:equality_proxy=off:general_splitting=off:inequality_splitting=0:\
  \naming=0"

val remote_vampire_full_proof_command =
  "vampire " ^ vampire_basic_options ^ " " ^ vampire_full_proof_options ^ " -t %d %s"

val vampire_config : atp_config =
  {exec = K (["VAMPIRE_HOME"], ["vampire"]),
   arguments = fn _ => fn full_proofs => fn sos => fn timeout => fn file_name => fn _ =>
     vampire_basic_options ^
     (if is_vampire_at_least_1_8 () andalso full_proofs then " " ^ vampire_full_proof_options
      else "") ^
     " -t " ^ string_of_int (to_secs 1 timeout) ^ " --input_file " ^ file_name
     |> sos = sosN ? prefix "--sos on ",
   proof_delims =
     [("=========== Refutation ==========",
       "======= End of refutation =======")] @
     tstp_proof_delims,
   known_failures =
     [(GaveUp, "UNPROVABLE"),
      (GaveUp, "CANNOT PROVE"),
      (Unprovable, "Satisfiability detected"),
      (Unprovable, "Termination reason: Satisfiable"),
      (Interrupted, "Aborted by signal SIGINT")] @
     known_szs_status_failures,
   prem_role = Conjecture,
   best_slices = fn ctxt =>
     (* FUDGE *)
     (if is_vampire_beyond_1_8 () then
        [(0.333, (((500, meshN), vampire_tff0, "mono_native", combs_or_liftingN, false), sosN)),
         (0.333, (((150, meshN), vampire_tff0, "poly_tags??", combs_or_liftingN, false), sosN)),
         (0.334, (((50, meshN), vampire_tff0, "mono_native", combs_or_liftingN, false), no_sosN))]
      else
        [(0.333, (((150, meshN), FOF, "poly_guards??", combs_or_liftingN, false), sosN)),
         (0.333, (((500, meshN), FOF, "mono_tags??", combs_or_liftingN, false), sosN)),
         (0.334, (((50, meshN), FOF, "mono_guards??", combs_or_liftingN, false), no_sosN))])
     |> Config.get ctxt force_sos ? (hd #> apfst (K 1.0) #> single),
   best_max_mono_iters = default_max_mono_iters,
   best_max_new_mono_instances = 2 * default_max_new_mono_instances (* FUDGE *)}

val vampire = (vampireN, fn () => vampire_config)

(* Z3 with TPTP syntax (half experimental, half legacy) *)

val z3_tff0 = TFF Monomorphic

val z3_tptp_config : atp_config =
  {exec = K (["Z3_TPTP_HOME"], ["z3_tptp"]),
   arguments = fn _ => fn _ => fn _ => fn timeout => fn file_name => fn _ =>
     "-proof -t:" ^ string_of_int (to_secs 1 timeout) ^ " -file:" ^ file_name,
   proof_delims = [("SZS status Theorem", "")],
   known_failures = known_szs_status_failures,
   prem_role = Hypothesis,
   best_slices =
     (* FUDGE *)
     K [(0.5, (((250, meshN), z3_tff0, "mono_native", combsN, false), "")),
        (0.25, (((125, mepoN), z3_tff0, "mono_native", combsN, false), "")),
        (0.125, (((62, mashN), z3_tff0, "mono_native", combsN, false), "")),
        (0.125, (((31, meshN), z3_tff0, "mono_native", combsN, false), ""))],
   best_max_mono_iters = default_max_mono_iters,
   best_max_new_mono_instances = 2 * default_max_new_mono_instances (* FUDGE *)}

val z3_tptp = (z3_tptpN, fn () => z3_tptp_config)


(* Zipperposition*)

val zipperposition_config : atp_config =
  {exec = K (["ZIPPERPOSITION_HOME"], ["zipperposition"]),
   arguments = fn _ => fn _ => fn _ => fn timeout => fn file_name => fn _ =>
       "-print none -proof tstp -print-types -timeout " ^
       string_of_int (to_secs 1 timeout) ^ " " ^ file_name,
   proof_delims = tstp_proof_delims,
   known_failures = known_szs_status_failures,
   prem_role = Hypothesis,
   best_slices = fn _ =>
     (* FUDGE *)
     [(1.0, (((100, ""), TFF Polymorphic, "poly_native", liftingN, false), ""))],
   best_max_mono_iters = default_max_mono_iters,
   best_max_new_mono_instances = default_max_new_mono_instances}

val zipperposition = (zipperpositionN, fn () => zipperposition_config)


(* Not really a prover: Experimental Polymorphic THF and DFG output *)

fun dummy_config prem_role format type_enc uncurried_aliases : atp_config =
  {exec = K (["ISABELLE_ATP"], ["scripts/dummy_atp"]),
   arguments = K (K (K (K (K (K ""))))),
   proof_delims = [],
   known_failures = known_szs_status_failures,
   prem_role = prem_role,
   best_slices =
     K [(1.0, (((200, ""), format, type_enc,
                if is_format_higher_order format then keep_lamsN
                else combsN, uncurried_aliases), ""))],
   best_max_mono_iters = default_max_mono_iters,
   best_max_new_mono_instances = default_max_new_mono_instances}

val dummy_thf_format = THF (Polymorphic, THF_With_Choice)

val dummy_thf_config = dummy_config Hypothesis dummy_thf_format "poly_native_higher" false
val dummy_thf = (dummy_thfN, fn () => dummy_thf_config)

val dummy_thf_ml_config = dummy_config Hypothesis dummy_thf_format "ml_poly_native_higher" false
val dummy_thf_ml = (dummy_thf_mlN, fn () => dummy_thf_ml_config)

val pirate_format = DFG Polymorphic
val remote_pirate_config : atp_config =
  {exec = K (["ISABELLE_ATP"], ["scripts/remote_pirate"]),
   arguments = fn _ => fn _ => fn _ => fn timeout => fn file_name => fn _ =>
     string_of_int (to_secs 1 timeout) ^ " " ^ file_name,
   proof_delims = [("Involved clauses:", "Involved clauses:")],
   known_failures = known_szs_status_failures,
   prem_role = #prem_role spass_config,
   best_slices = K [(1.0, (((200, ""), pirate_format, "tc_native", combsN, true), ""))],
   best_max_mono_iters = default_max_mono_iters,
   best_max_new_mono_instances = default_max_new_mono_instances}
val remote_pirate = (remote_prefix ^ pirateN, fn () => remote_pirate_config)


(* Remote ATP invocation via SystemOnTPTP *)

val remote_systems = Synchronized.var "atp_remote_systems" ([] : string list)

fun get_remote_systems () =
  TimeLimit.timeLimit (seconds 10.0) (fn () =>
    (case Isabelle_System.bash_output "\"$ISABELLE_ATP/scripts/remote_atp\" -w 2>&1" of
      (output, 0) => split_lines output
    | (output, _) =>
      (warning
         (case extract_known_atp_failure known_perl_failures output of
           SOME failure => string_of_atp_failure failure
         | NONE => trim_line output ^ "."); []))) ()
  handle TimeLimit.TimeOut => []

fun find_remote_system name [] systems =
    find_first (String.isPrefix (name ^ "---")) systems
  | find_remote_system name (version :: versions) systems =
    case find_first (String.isPrefix (name ^ "---" ^ version)) systems of
      NONE => find_remote_system name versions systems
    | res => res

fun get_remote_system name versions =
  Synchronized.change_result remote_systems
      (fn systems => (if null systems then get_remote_systems () else systems)
                     |> `(`(find_remote_system name versions)))

fun the_remote_system name versions =
  (case get_remote_system name versions of
    (SOME sys, _) => sys
  | (NONE, []) => error "SystemOnTPTP is not available."
  | (NONE, syss) =>
    (case syss |> filter_out (String.isPrefix "%") |> filter_out (curry (op =) "") of
      [] => error "SystemOnTPTP is currently not available."
    | [msg] => error ("SystemOnTPTP is currently not available: " ^ msg ^ ".")
    | syss =>
      error ("System " ^ quote name ^ " is not available at SystemOnTPTP.\n(Available systems: " ^
        commas_quote syss ^ ".)")))

val max_remote_secs = 240 (* give Geoff Sutcliffe's servers a break *)

fun remote_config system_name system_versions proof_delims known_failures prem_role best_slice =
  {exec = K (["ISABELLE_ATP"], ["scripts/remote_atp"]),
   arguments = fn _ => fn full_proofs => fn full_proof_command => fn timeout => fn file_name => fn _ =>
     (if full_proofs andalso full_proof_command <> "" then "-c " ^ quote full_proof_command ^ " "
      else "") ^
     "-s " ^ the_remote_system system_name system_versions ^ " " ^
     "-t " ^ string_of_int (Int.min (max_remote_secs, to_secs 1 timeout)) ^
     " " ^ file_name,
   proof_delims = union (op =) tstp_proof_delims proof_delims,
   known_failures = known_failures @ known_perl_failures @ known_says_failures,
   prem_role = prem_role,
   best_slices = fn ctxt => [(1.0, best_slice ctxt)],
   best_max_mono_iters = default_max_mono_iters,
   best_max_new_mono_instances = default_max_new_mono_instances} : atp_config

fun remotify_config system_name system_versions best_slice
    ({proof_delims, known_failures, prem_role, ...} : atp_config) =
  remote_config system_name system_versions proof_delims known_failures prem_role best_slice

fun remote_atp name system_name system_versions proof_delims known_failures prem_role best_slice =
  (remote_prefix ^ name, fn () =>
     remote_config system_name system_versions proof_delims known_failures prem_role best_slice)
fun remotify_atp (name, config) system_name system_versions best_slice =
  (remote_prefix ^ name, remotify_config system_name system_versions best_slice o config)

fun gen_remote_waldmeister name type_enc =
  remote_atp name "Waldmeister" ["710"] tstp_proof_delims
    ([(OutOfResources, "Too many function symbols"),
      (Inappropriate, "****  Unexpected end of file."),
      (Crashed, "Unrecoverable Segmentation Fault")]
     @ known_szs_status_failures)
    Hypothesis
    (K (((50, ""), CNF_UEQ, type_enc, combsN, false), "") (* FUDGE *))

val explicit_tff0 = TFF Monomorphic

val remote_agsyhol =
  remotify_atp agsyhol "agsyHOL" ["1.0", "1"]
    (K (((60, ""), agsyhol_thf0, "mono_native_higher", keep_lamsN, false), "") (* FUDGE *))
val remote_e =
  remotify_atp e "EP" ["1.8", "1.7", "1.6", "1.5", "1"]
    (K (((750, ""), FOF, "mono_tags??", combsN, false), "") (* FUDGE *))
val remote_iprover =
  remotify_atp iprover "iProver" ["0.99"]
    (K (((150, ""), FOF, "mono_guards??", liftingN, false), "") (* FUDGE *))
val remote_iprover_eq =
  remotify_atp iprover_eq "iProver-Eq" ["0.8"]
    (K (((150, ""), FOF, "mono_guards??", liftingN, false), "") (* FUDGE *))
val remote_leo2 =
  remotify_atp leo2 "LEO-II" ["1.5.0", "1.4", "1.3", "1.2", "1"]
    (K (((40, ""), leo2_thf0, "mono_native_higher", liftingN, false), "") (* FUDGE *))
val remote_satallax =
  remotify_atp satallax "Satallax" ["2.7", "2.3", "2"]
    (K (((60, ""), satallax_thf0, "mono_native_higher", keep_lamsN, false), "") (* FUDGE *))
val remote_vampire =
  remotify_atp vampire "Vampire" ["3.0", "2.6", "2.5"]
    (K (((400, ""), vampire_tff0, "mono_native", combs_or_liftingN, false), remote_vampire_full_proof_command) (* FUDGE *))
val remote_e_sine =
  remote_atp e_sineN "SInE" ["0.4"] [] (#known_failures e_config) Conjecture
    (K (((500, ""), FOF, "mono_guards??", combsN, false), "") (* FUDGE *))
val remote_snark =
  remote_atp snarkN "SNARK" ["20120808r022", "20080805r029", "20080805r024"]
    [("refutation.", "end_refutation.")] [] Hypothesis
    (K (((100, ""), explicit_tff0, "mono_native", liftingN, false), "") (* FUDGE *))
val remote_e_tofof =
  remote_atp e_tofofN "ToFoF" ["0.1"] [] (#known_failures e_config) Hypothesis
    (K (((150, ""), explicit_tff0, "mono_native", liftingN, false), "") (* FUDGE *))
val remote_waldmeister = gen_remote_waldmeister waldmeisterN "raw_mono_tags??"
val remote_waldmeister_new = gen_remote_waldmeister waldmeister_newN "mono_args"


(* Setup *)

fun add_atp (name, config) thy =
  Data.map (Symtab.update_new (name, (config, stamp ()))) thy
  handle Symtab.DUP name => error ("Duplicate ATP: " ^ quote name ^ ".")

fun get_atp thy name =
  fst (the (Symtab.lookup (Data.get thy) name))
  handle Option.Option => error ("Unknown ATP: " ^ name ^ ".")

val supported_atps = Symtab.keys o Data.get

fun is_atp_installed thy name =
  let val {exec, ...} = get_atp thy name () in
    exists (fn var => getenv var <> "") (fst (exec false))
  end

fun refresh_systems_on_tptp () =
  Synchronized.change remote_systems (fn _ => get_remote_systems ())

fun effective_term_order ctxt atp =
  let val ord = Config.get ctxt term_order in
    if ord = smartN then
      {is_lpo = false, gen_weights = (atp = spassN), gen_prec = (atp = spassN),
       gen_simp = String.isSuffix pirateN atp}
    else
      let val is_lpo = String.isSubstring lpoN ord in
        {is_lpo = is_lpo, gen_weights = not is_lpo andalso String.isSubstring xweightsN ord,
         gen_prec = String.isSubstring xprecN ord, gen_simp = String.isSubstring xsimpN ord}
      end
  end

val atps =
  [agsyhol, alt_ergo, e, e_males, e_par, iprover, iprover_eq, leo2, satallax, spass, vampire,
   z3_tptp, zipperposition, dummy_thf, dummy_thf_ml, remote_agsyhol, remote_e, remote_e_sine,
   remote_e_tofof, remote_iprover, remote_iprover_eq, remote_leo2, remote_satallax, remote_vampire,
   remote_snark, remote_pirate, remote_waldmeister, remote_waldmeister_new]

val _ = Theory.setup (fold add_atp atps)

end;
