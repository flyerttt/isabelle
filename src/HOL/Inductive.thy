(*  Title:      HOL/Inductive.thy
    Author:     Markus Wenzel, TU Muenchen
*)

section \<open>Knaster-Tarski Fixpoint Theorem and inductive definitions\<close>

theory Inductive
imports Complete_Lattices Ctr_Sugar
keywords
  "inductive" "coinductive" "inductive_cases" "inductive_simps" :: thy_decl and
  "monos" and
  "print_inductives" :: diag and
  "old_rep_datatype" :: thy_goal and
  "primrec" :: thy_decl
begin

subsection \<open>Least and greatest fixed points\<close>

context complete_lattice
begin

definition
  lfp :: "('a \<Rightarrow> 'a) \<Rightarrow> 'a" where
  "lfp f = Inf {u. f u \<le> u}"    \<comment>\<open>least fixed point\<close>

definition
  gfp :: "('a \<Rightarrow> 'a) \<Rightarrow> 'a" where
  "gfp f = Sup {u. u \<le> f u}"    \<comment>\<open>greatest fixed point\<close>


subsection\<open>Proof of Knaster-Tarski Theorem using @{term lfp}\<close>

text\<open>@{term "lfp f"} is the least upper bound of
      the set @{term "{u. f(u) \<le> u}"}\<close>

lemma lfp_lowerbound: "f A \<le> A ==> lfp f \<le> A"
  by (auto simp add: lfp_def intro: Inf_lower)

lemma lfp_greatest: "(!!u. f u \<le> u ==> A \<le> u) ==> A \<le> lfp f"
  by (auto simp add: lfp_def intro: Inf_greatest)

end

lemma lfp_lemma2: "mono f ==> f (lfp f) \<le> lfp f"
  by (iprover intro: lfp_greatest order_trans monoD lfp_lowerbound)

lemma lfp_lemma3: "mono f ==> lfp f \<le> f (lfp f)"
  by (iprover intro: lfp_lemma2 monoD lfp_lowerbound)

lemma lfp_unfold: "mono f ==> lfp f = f (lfp f)"
  by (iprover intro: order_antisym lfp_lemma2 lfp_lemma3)

lemma lfp_const: "lfp (\<lambda>x. t) = t"
  by (rule lfp_unfold) (simp add:mono_def)


subsection \<open>General induction rules for least fixed points\<close>

lemma lfp_ordinal_induct[case_names mono step union]:
  fixes f :: "'a::complete_lattice \<Rightarrow> 'a"
  assumes mono: "mono f"
  and P_f: "\<And>S. P S \<Longrightarrow> S \<le> lfp f \<Longrightarrow> P (f S)"
  and P_Union: "\<And>M. \<forall>S\<in>M. P S \<Longrightarrow> P (Sup M)"
  shows "P (lfp f)"
proof -
  let ?M = "{S. S \<le> lfp f \<and> P S}"
  have "P (Sup ?M)" using P_Union by simp
  also have "Sup ?M = lfp f"
  proof (rule antisym)
    show "Sup ?M \<le> lfp f" by (blast intro: Sup_least)
    hence "f (Sup ?M) \<le> f (lfp f)" by (rule mono [THEN monoD])
    hence "f (Sup ?M) \<le> lfp f" using mono [THEN lfp_unfold] by simp
    hence "f (Sup ?M) \<in> ?M" using P_Union by simp (intro P_f Sup_least, auto)
    hence "f (Sup ?M) \<le> Sup ?M" by (rule Sup_upper)
    thus "lfp f \<le> Sup ?M" by (rule lfp_lowerbound)
  qed
  finally show ?thesis .
qed 

theorem lfp_induct:
  assumes mono: "mono f" and ind: "f (inf (lfp f) P) \<le> P"
  shows "lfp f \<le> P"
proof (induction rule: lfp_ordinal_induct)
  case (step S) then show ?case
    by (intro order_trans[OF _ ind] monoD[OF mono]) auto
qed (auto intro: mono Sup_least)

lemma lfp_induct_set:
  assumes lfp: "a: lfp(f)"
    and mono: "mono(f)"
    and indhyp: "!!x. [| x: f(lfp(f) Int {x. P(x)}) |] ==> P(x)"
  shows "P(a)"
  by (rule lfp_induct [THEN subsetD, THEN CollectD, OF mono _ lfp])
     (auto simp: intro: indhyp)

lemma lfp_ordinal_induct_set: 
  assumes mono: "mono f"
    and P_f: "!!S. P S ==> P(f S)"
    and P_Union: "!!M. !S:M. P S ==> P (\<Union>M)"
  shows "P(lfp f)"
  using assms by (rule lfp_ordinal_induct)


text\<open>Definition forms of \<open>lfp_unfold\<close> and \<open>lfp_induct\<close>, 
    to control unfolding\<close>

lemma def_lfp_unfold: "[| h==lfp(f);  mono(f) |] ==> h = f(h)"
  by (auto intro!: lfp_unfold)

lemma def_lfp_induct: 
    "[| A == lfp(f); mono(f);
        f (inf A P) \<le> P
     |] ==> A \<le> P"
  by (blast intro: lfp_induct)

lemma def_lfp_induct_set: 
    "[| A == lfp(f);  mono(f);   a:A;                    
        !!x. [| x: f(A Int {x. P(x)}) |] ==> P(x)         
     |] ==> P(a)"
  by (blast intro: lfp_induct_set)

(*Monotonicity of lfp!*)
lemma lfp_mono: "(!!Z. f Z \<le> g Z) ==> lfp f \<le> lfp g"
  by (rule lfp_lowerbound [THEN lfp_greatest], blast intro: order_trans)


subsection \<open>Proof of Knaster-Tarski Theorem using @{term gfp}\<close>

text\<open>@{term "gfp f"} is the greatest lower bound of 
      the set @{term "{u. u \<le> f(u)}"}\<close>

lemma gfp_upperbound: "X \<le> f X ==> X \<le> gfp f"
  by (auto simp add: gfp_def intro: Sup_upper)

lemma gfp_least: "(!!u. u \<le> f u ==> u \<le> X) ==> gfp f \<le> X"
  by (auto simp add: gfp_def intro: Sup_least)

lemma gfp_lemma2: "mono f ==> gfp f \<le> f (gfp f)"
  by (iprover intro: gfp_least order_trans monoD gfp_upperbound)

lemma gfp_lemma3: "mono f ==> f (gfp f) \<le> gfp f"
  by (iprover intro: gfp_lemma2 monoD gfp_upperbound)

lemma gfp_unfold: "mono f ==> gfp f = f (gfp f)"
  by (iprover intro: order_antisym gfp_lemma2 gfp_lemma3)


subsection \<open>Coinduction rules for greatest fixed points\<close>

text\<open>weak version\<close>
lemma weak_coinduct: "[| a: X;  X \<subseteq> f(X) |] ==> a : gfp(f)"
  by (rule gfp_upperbound [THEN subsetD]) auto

lemma weak_coinduct_image: "!!X. [| a : X; g`X \<subseteq> f (g`X) |] ==> g a : gfp f"
  apply (erule gfp_upperbound [THEN subsetD])
  apply (erule imageI)
  done

lemma coinduct_lemma:
     "[| X \<le> f (sup X (gfp f));  mono f |] ==> sup X (gfp f) \<le> f (sup X (gfp f))"
  apply (frule gfp_lemma2)
  apply (drule mono_sup)
  apply (rule le_supI)
  apply assumption
  apply (rule order_trans)
  apply (rule order_trans)
  apply assumption
  apply (rule sup_ge2)
  apply assumption
  done

text\<open>strong version, thanks to Coen and Frost\<close>
lemma coinduct_set: "[| mono(f);  a: X;  X \<subseteq> f(X Un gfp(f)) |] ==> a : gfp(f)"
  by (rule weak_coinduct[rotated], rule coinduct_lemma) blast+

lemma gfp_fun_UnI2: "[| mono(f);  a: gfp(f) |] ==> a: f(X Un gfp(f))"
  by (blast dest: gfp_lemma2 mono_Un)

lemma gfp_ordinal_induct[case_names mono step union]:
  fixes f :: "'a::complete_lattice \<Rightarrow> 'a"
  assumes mono: "mono f"
  and P_f: "\<And>S. P S \<Longrightarrow> gfp f \<le> S \<Longrightarrow> P (f S)"
  and P_Union: "\<And>M. \<forall>S\<in>M. P S \<Longrightarrow> P (Inf M)"
  shows "P (gfp f)"
proof -
  let ?M = "{S. gfp f \<le> S \<and> P S}"
  have "P (Inf ?M)" using P_Union by simp
  also have "Inf ?M = gfp f"
  proof (rule antisym)
    show "gfp f \<le> Inf ?M" by (blast intro: Inf_greatest)
    hence "f (gfp f) \<le> f (Inf ?M)" by (rule mono [THEN monoD])
    hence "gfp f \<le> f (Inf ?M)" using mono [THEN gfp_unfold] by simp
    hence "f (Inf ?M) \<in> ?M" using P_Union by simp (intro P_f Inf_greatest, auto)
    hence "Inf ?M \<le> f (Inf ?M)" by (rule Inf_lower)
    thus "Inf ?M \<le> gfp f" by (rule gfp_upperbound)
  qed
  finally show ?thesis .
qed 

lemma coinduct: assumes mono: "mono f" and ind: "X \<le> f (sup X (gfp f))" shows "X \<le> gfp f"
proof (induction rule: gfp_ordinal_induct)
  case (step S) then show ?case
    by (intro order_trans[OF ind _] monoD[OF mono]) auto
qed (auto intro: mono Inf_greatest)

subsection \<open>Even Stronger Coinduction Rule, by Martin Coen\<close>

text\<open>Weakens the condition @{term "X \<subseteq> f(X)"} to one expressed using both
  @{term lfp} and @{term gfp}\<close>

lemma coinduct3_mono_lemma: "mono(f) ==> mono(%x. f(x) Un X Un B)"
by (iprover intro: subset_refl monoI Un_mono monoD)

lemma coinduct3_lemma:
     "[| X \<subseteq> f(lfp(%x. f(x) Un X Un gfp(f)));  mono(f) |]
      ==> lfp(%x. f(x) Un X Un gfp(f)) \<subseteq> f(lfp(%x. f(x) Un X Un gfp(f)))"
apply (rule subset_trans)
apply (erule coinduct3_mono_lemma [THEN lfp_lemma3])
apply (rule Un_least [THEN Un_least])
apply (rule subset_refl, assumption)
apply (rule gfp_unfold [THEN equalityD1, THEN subset_trans], assumption)
apply (rule monoD, assumption)
apply (subst coinduct3_mono_lemma [THEN lfp_unfold], auto)
done

lemma coinduct3: 
  "[| mono(f);  a:X;  X \<subseteq> f(lfp(%x. f(x) Un X Un gfp(f))) |] ==> a : gfp(f)"
apply (rule coinduct3_lemma [THEN [2] weak_coinduct])
apply (rule coinduct3_mono_lemma [THEN lfp_unfold, THEN ssubst])
apply (simp_all)
done

text\<open>Definition forms of \<open>gfp_unfold\<close> and \<open>coinduct\<close>, 
    to control unfolding\<close>

lemma def_gfp_unfold: "[| A==gfp(f);  mono(f) |] ==> A = f(A)"
  by (auto intro!: gfp_unfold)

lemma def_coinduct:
     "[| A==gfp(f);  mono(f);  X \<le> f(sup X A) |] ==> X \<le> A"
  by (iprover intro!: coinduct)

lemma def_coinduct_set:
     "[| A==gfp(f);  mono(f);  a:X;  X \<subseteq> f(X Un A) |] ==> a: A"
  by (auto intro!: coinduct_set)

(*The version used in the induction/coinduction package*)
lemma def_Collect_coinduct:
    "[| A == gfp(%w. Collect(P(w)));  mono(%w. Collect(P(w)));   
        a: X;  !!z. z: X ==> P (X Un A) z |] ==>  
     a : A"
  by (erule def_coinduct_set) auto

lemma def_coinduct3:
    "[| A==gfp(f); mono(f);  a:X;  X \<subseteq> f(lfp(%x. f(x) Un X Un A)) |] ==> a: A"
  by (auto intro!: coinduct3)

text\<open>Monotonicity of @{term gfp}!\<close>
lemma gfp_mono: "(!!Z. f Z \<le> g Z) ==> gfp f \<le> gfp g"
  by (rule gfp_upperbound [THEN gfp_least], blast intro: order_trans)

subsection \<open>Rules for fixed point calculus\<close>


lemma lfp_rolling:
  assumes "mono g" "mono f"
  shows "g (lfp (\<lambda>x. f (g x))) = lfp (\<lambda>x. g (f x))"
proof (rule antisym)
  have *: "mono (\<lambda>x. f (g x))"
    using assms by (auto simp: mono_def)

  show "lfp (\<lambda>x. g (f x)) \<le> g (lfp (\<lambda>x. f (g x)))"
    by (rule lfp_lowerbound) (simp add: lfp_unfold[OF *, symmetric])

  show "g (lfp (\<lambda>x. f (g x))) \<le> lfp (\<lambda>x. g (f x))"
  proof (rule lfp_greatest)
    fix u assume "g (f u) \<le> u"
    moreover then have "g (lfp (\<lambda>x. f (g x))) \<le> g (f u)"
      by (intro assms[THEN monoD] lfp_lowerbound)
    ultimately show "g (lfp (\<lambda>x. f (g x))) \<le> u"
      by auto
  qed
qed

lemma lfp_lfp:
  assumes f: "\<And>x y w z. x \<le> y \<Longrightarrow> w \<le> z \<Longrightarrow> f x w \<le> f y z"
  shows "lfp (\<lambda>x. lfp (f x)) = lfp (\<lambda>x. f x x)"
proof (rule antisym)
  have *: "mono (\<lambda>x. f x x)"
    by (blast intro: monoI f)
  show "lfp (\<lambda>x. lfp (f x)) \<le> lfp (\<lambda>x. f x x)"
    by (intro lfp_lowerbound) (simp add: lfp_unfold[OF *, symmetric])
  show "lfp (\<lambda>x. lfp (f x)) \<ge> lfp (\<lambda>x. f x x)" (is "?F \<ge> _")
  proof (intro lfp_lowerbound)
    have *: "?F = lfp (f ?F)"
      by (rule lfp_unfold) (blast intro: monoI lfp_mono f)
    also have "\<dots> = f ?F (lfp (f ?F))"
      by (rule lfp_unfold) (blast intro: monoI lfp_mono f)
    finally show "f ?F ?F \<le> ?F"
      by (simp add: *[symmetric])
  qed
qed

lemma gfp_rolling:
  assumes "mono g" "mono f"
  shows "g (gfp (\<lambda>x. f (g x))) = gfp (\<lambda>x. g (f x))"
proof (rule antisym)
  have *: "mono (\<lambda>x. f (g x))"
    using assms by (auto simp: mono_def)
  show "g (gfp (\<lambda>x. f (g x))) \<le> gfp (\<lambda>x. g (f x))"
    by (rule gfp_upperbound) (simp add: gfp_unfold[OF *, symmetric])

  show "gfp (\<lambda>x. g (f x)) \<le> g (gfp (\<lambda>x. f (g x)))"
  proof (rule gfp_least)
    fix u assume "u \<le> g (f u)"
    moreover then have "g (f u) \<le> g (gfp (\<lambda>x. f (g x)))"
      by (intro assms[THEN monoD] gfp_upperbound)
    ultimately show "u \<le> g (gfp (\<lambda>x. f (g x)))"
      by auto
  qed
qed

lemma gfp_gfp:
  assumes f: "\<And>x y w z. x \<le> y \<Longrightarrow> w \<le> z \<Longrightarrow> f x w \<le> f y z"
  shows "gfp (\<lambda>x. gfp (f x)) = gfp (\<lambda>x. f x x)"
proof (rule antisym)
  have *: "mono (\<lambda>x. f x x)"
    by (blast intro: monoI f)
  show "gfp (\<lambda>x. f x x) \<le> gfp (\<lambda>x. gfp (f x))"
    by (intro gfp_upperbound) (simp add: gfp_unfold[OF *, symmetric])
  show "gfp (\<lambda>x. gfp (f x)) \<le> gfp (\<lambda>x. f x x)" (is "?F \<le> _")
  proof (intro gfp_upperbound)
    have *: "?F = gfp (f ?F)"
      by (rule gfp_unfold) (blast intro: monoI gfp_mono f)
    also have "\<dots> = f ?F (gfp (f ?F))"
      by (rule gfp_unfold) (blast intro: monoI gfp_mono f)
    finally show "?F \<le> f ?F ?F"
      by (simp add: *[symmetric])
  qed
qed

subsection \<open>Inductive predicates and sets\<close>

text \<open>Package setup.\<close>

lemmas basic_monos =
  subset_refl imp_refl disj_mono conj_mono ex_mono all_mono if_bool_eq_conj
  Collect_mono in_mono vimage_mono

ML_file "Tools/inductive.ML"

lemmas [mono] =
  imp_refl disj_mono conj_mono ex_mono all_mono if_bool_eq_conj
  imp_mono not_mono
  Ball_def Bex_def
  induct_rulify_fallback


subsection \<open>Inductive datatypes and primitive recursion\<close>

text \<open>Package setup.\<close>

ML_file "Tools/Old_Datatype/old_datatype_aux.ML"
ML_file "Tools/Old_Datatype/old_datatype_prop.ML"
ML_file "Tools/Old_Datatype/old_datatype_data.ML"
ML_file "Tools/Old_Datatype/old_rep_datatype.ML"
ML_file "Tools/Old_Datatype/old_datatype_codegen.ML"
ML_file "Tools/Old_Datatype/old_primrec.ML"

ML_file "Tools/BNF/bnf_fp_rec_sugar_util.ML"
ML_file "Tools/BNF/bnf_lfp_rec_sugar.ML"

text \<open>Lambda-abstractions with pattern matching:\<close>
syntax (ASCII)
  "_lam_pats_syntax" :: "cases_syn \<Rightarrow> 'a \<Rightarrow> 'b"  ("(%_)" 10)
syntax
  "_lam_pats_syntax" :: "cases_syn \<Rightarrow> 'a \<Rightarrow> 'b"  ("(\<lambda>_)" 10)
parse_translation \<open>
  let
    fun fun_tr ctxt [cs] =
      let
        val x = Syntax.free (fst (Name.variant "x" (Term.declare_term_frees cs Name.context)));
        val ft = Case_Translation.case_tr true ctxt [x, cs];
      in lambda x ft end
  in [(@{syntax_const "_lam_pats_syntax"}, fun_tr)] end
\<close>

end
