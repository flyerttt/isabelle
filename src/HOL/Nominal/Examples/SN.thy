(* $Id$ *)

theory SN
imports Lam_Funs
begin

text {* Strong Normalisation proof from the Proofs and Types book *}

section {* Beta Reduction *}

lemma subst_rename: 
  assumes a: "c\<sharp>t1"
  shows "t1[a::=t2] = ([(c,a)]\<bullet>t1)[c::=t2]"
using a
by (nominal_induct t1 avoiding: a c t2 rule: lam.induct)
   (auto simp add: calc_atm fresh_atm abs_fresh)

lemma forget: 
  assumes a: "a\<sharp>t1"
  shows "t1[a::=t2] = t1"
  using a
by (nominal_induct t1 avoiding: a t2 rule: lam.induct)
   (auto simp add: abs_fresh fresh_atm)

lemma fresh_fact: 
  fixes a::"name"
  assumes a: "a\<sharp>t1"
  and     b: "a\<sharp>t2"
  shows "a\<sharp>t1[b::=t2]"
using a b
by (nominal_induct t1 avoiding: a b t2 rule: lam.induct)
   (auto simp add: abs_fresh fresh_atm)

lemma fresh_fact': 
  fixes a::"name"
  assumes a: "a\<sharp>t2"
  shows "a\<sharp>t1[a::=t2]"
using a 
by (nominal_induct t1 avoiding: a t2 rule: lam.induct)
   (auto simp add: abs_fresh fresh_atm)

lemma subst_lemma:  
  assumes a: "x\<noteq>y"
  and     b: "x\<sharp>L"
  shows "M[x::=N][y::=L] = M[y::=L][x::=N[y::=L]]"
using a b
by (nominal_induct M avoiding: x y N L rule: lam.induct)
   (auto simp add: fresh_fact forget)

lemma id_subs: 
  shows "t[x::=Var x] = t"
  by (nominal_induct t avoiding: x rule: lam.induct)
     (simp_all add: fresh_atm)

lemma psubst_subst:
  assumes h:"c\<sharp>\<theta>"
  shows "(\<theta><t>)[c::=s] = ((c,s)#\<theta>)<t>"
  using h
by (nominal_induct t avoiding: \<theta> c s rule: lam.induct)
   (auto simp add: fresh_list_cons fresh_atm forget lookup_fresh lookup_fresh')
 
inductive 
  Beta :: "lam\<Rightarrow>lam\<Rightarrow>bool" (" _ \<longrightarrow>\<^isub>\<beta> _" [80,80] 80)
where
  b1[intro!]: "s1\<longrightarrow>\<^isub>\<beta>s2 \<Longrightarrow> (App s1 t)\<longrightarrow>\<^isub>\<beta>(App s2 t)"
| b2[intro!]: "s1\<longrightarrow>\<^isub>\<beta>s2 \<Longrightarrow> (App t s1)\<longrightarrow>\<^isub>\<beta>(App t s2)"
| b3[intro!]: "s1\<longrightarrow>\<^isub>\<beta>s2 \<Longrightarrow> (Lam [a].s1)\<longrightarrow>\<^isub>\<beta> (Lam [a].s2)"
| b4[intro!]: "a\<sharp>s2 \<Longrightarrow>(App (Lam [a].s1) s2)\<longrightarrow>\<^isub>\<beta>(s1[a::=s2])"

equivariance Beta

nominal_inductive Beta
  by (simp_all add: abs_fresh fresh_fact')

abbreviation 
  "Beta_star"  :: "lam\<Rightarrow>lam\<Rightarrow>bool" (" _ \<longrightarrow>\<^isub>\<beta>\<^sup>* _" [80,80] 80) 
where
  "t1 \<longrightarrow>\<^isub>\<beta>\<^sup>* t2 \<equiv> Beta\<^sup>*\<^sup>* t1 t2"

lemma supp_beta: 
  assumes a: "t\<longrightarrow>\<^isub>\<beta> s"
  shows "(supp s)\<subseteq>((supp t)::name set)"
using a
by (induct)
   (auto intro!: simp add: abs_supp lam.supp subst_supp)

lemma beta_abs: "Lam [a].t\<longrightarrow>\<^isub>\<beta> t'\<Longrightarrow>\<exists>t''. t'=Lam [a].t'' \<and> t\<longrightarrow>\<^isub>\<beta> t''"
apply(ind_cases "Lam [a].t  \<longrightarrow>\<^isub>\<beta> t'")
apply(auto simp add: lam.distinct lam.inject)
apply(auto simp add: alpha)
apply(rule_tac x="[(a,aa)]\<bullet>s2" in exI)
apply(rule conjI)
apply(rule sym)
apply(rule pt_bij2[OF pt_name_inst, OF at_name_inst])
apply(simp)
apply(rule pt_name3)
apply(simp add: at_ds5[OF at_name_inst])
apply(rule conjI)
apply(simp add: pt_fresh_left[OF pt_name_inst, OF at_name_inst] calc_atm)
apply(force dest!: supp_beta simp add: fresh_def)
apply(force intro!: eqvts)
done

lemma beta_subst: 
  assumes a: "M \<longrightarrow>\<^isub>\<beta> M'"
  shows "M[x::=N]\<longrightarrow>\<^isub>\<beta> M'[x::=N]" 
using a
by (nominal_induct M M' avoiding: x N rule: Beta.strong_induct)
   (auto simp add: fresh_atm subst_lemma fresh_fact)

section {* types *}

nominal_datatype ty =
    TVar "nat"
  | TArr "ty" "ty" (infix "\<rightarrow>" 200)

lemma perm_ty:
  fixes pi ::"name prm"
  and   \<tau>  ::"ty"
  shows "pi\<bullet>\<tau> = \<tau>"
by (nominal_induct \<tau> rule: ty.induct) 
   (simp_all add: perm_nat_def)

lemma fresh_ty:
  fixes a ::"name"
  and   \<tau>  ::"ty"
  shows "a\<sharp>\<tau>"
  by (simp add: fresh_def perm_ty supp_def)

(* domain of a typing context *)

fun
  "dom_ty" :: "(name\<times>ty) list \<Rightarrow> (name list)"
where
  "dom_ty []    = []"
| "dom_ty ((x,\<tau>)#\<Gamma>) = (x)#(dom_ty \<Gamma>)" 


(* valid contexts *)

inductive 
  valid :: "(name\<times>ty) list \<Rightarrow> bool"
where
  v1[intro]: "valid []"
| v2[intro]: "\<lbrakk>valid \<Gamma>;a\<sharp>\<Gamma>\<rbrakk>\<Longrightarrow> valid ((a,\<sigma>)#\<Gamma>)"

equivariance valid 

inductive_cases valid_elim[elim]: "valid ((a,\<tau>)#\<Gamma>)"

(* typing judgements *)

lemma fresh_context: 
  fixes  \<Gamma> :: "(name\<times>ty)list"
  and    a :: "name"
  assumes a: "a\<sharp>\<Gamma>"
  shows "\<not>(\<exists>\<tau>::ty. (a,\<tau>)\<in>set \<Gamma>)"
using a
apply(induct \<Gamma>)
apply(auto simp add: fresh_prod fresh_list_cons fresh_atm)
done

inductive 
  typing :: "(name\<times>ty) list\<Rightarrow>lam\<Rightarrow>ty\<Rightarrow>bool" ("_ \<turnstile> _ : _" [60,60,60] 60)
where
  t1[intro]: "\<lbrakk>valid \<Gamma>; (a,\<tau>)\<in>set \<Gamma>\<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> Var a : \<tau>"
| t2[intro]: "\<lbrakk>\<Gamma> \<turnstile> t1 : \<tau>\<rightarrow>\<sigma>; \<Gamma> \<turnstile> t2 : \<tau>\<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> App t1 t2 : \<sigma>"
| t3[intro]: "\<lbrakk>a\<sharp>\<Gamma>;((a,\<tau>)#\<Gamma>) \<turnstile> t : \<sigma>\<rbrakk> \<Longrightarrow> \<Gamma> \<turnstile> Lam [a].t : \<tau>\<rightarrow>\<sigma>"

equivariance typing

nominal_inductive typing
  by (simp_all add: abs_fresh fresh_ty)

abbreviation
  "sub" :: "(name\<times>ty) list \<Rightarrow> (name\<times>ty) list \<Rightarrow> bool" ("_ \<subseteq> _" [60,60] 60) 
where
  "\<Gamma>1 \<subseteq> \<Gamma>2 \<equiv> \<forall>a \<sigma>. (a,\<sigma>)\<in>set \<Gamma>1 \<longrightarrow>  (a,\<sigma>)\<in>set \<Gamma>2"

subsection {* some facts about beta *}

constdefs
  "NORMAL" :: "lam \<Rightarrow> bool"
  "NORMAL t \<equiv> \<not>(\<exists>t'. t\<longrightarrow>\<^isub>\<beta> t')"

lemma NORMAL_Var:
  shows "NORMAL (Var a)"
proof -
  { assume "\<exists>t'. (Var a) \<longrightarrow>\<^isub>\<beta> t'"
    then obtain t' where "(Var a) \<longrightarrow>\<^isub>\<beta> t'" by blast
    hence False by (cases, auto) 
  }
  thus "NORMAL (Var a)" by (force simp add: NORMAL_def)
qed

constdefs
  "SN" :: "lam \<Rightarrow> bool"
  "SN t \<equiv> termip Beta t"

lemma SN_preserved: "\<lbrakk>SN(t1);t1\<longrightarrow>\<^isub>\<beta> t2\<rbrakk>\<Longrightarrow>SN(t2)"
apply(simp add: SN_def)
apply(drule_tac a="t2" in accp_downward)
apply(auto)
done

lemma SN_intro: "(\<forall>t2. t1\<longrightarrow>\<^isub>\<beta>t2 \<longrightarrow> SN(t2))\<Longrightarrow>SN(t1)"
apply(simp add: SN_def)
apply(rule accp.accI)
apply(auto)
done

section {* Candidates *}

consts
  RED :: "ty \<Rightarrow> lam set"

nominal_primrec
  "RED (TVar X) = {t. SN(t)}"
  "RED (\<tau>\<rightarrow>\<sigma>) =   {t. \<forall>u. (u\<in>RED \<tau> \<longrightarrow> (App t u)\<in>RED \<sigma>)}"
apply(rule TrueI)+
done

constdefs
  NEUT :: "lam \<Rightarrow> bool"
  "NEUT t \<equiv> (\<exists>a. t=Var a)\<or>(\<exists>t1 t2. t=App t1 t2)" 

(* a slight hack to get the first element of applications *)
inductive 
  FST :: "lam\<Rightarrow>lam\<Rightarrow>bool" (" _ \<guillemotright> _" [80,80] 80)
where
  fst[intro!]:  "(App t s) \<guillemotright> t"

lemma fst_elim[elim!]: 
  shows "(App t s) \<guillemotright> t' \<Longrightarrow> t=t'"
apply(ind_cases "App t s \<guillemotright> t'")
apply(simp add: lam.inject)
done

lemma qq3: "SN(App t s)\<Longrightarrow>SN(t)"
apply(simp add: SN_def)
apply(subgoal_tac "\<forall>z. (App t s \<guillemotright> z) \<longrightarrow> termip Beta z")(*A*)
apply(force)
(*A*)
apply(erule accp_induct)
apply(clarify)
apply(ind_cases "x \<guillemotright> z" for x z)
apply(clarify)
apply(rule accp.accI)
apply(auto intro: b1)
done

section {* Candidates *}

constdefs
  "CR1" :: "ty \<Rightarrow> bool"
  "CR1 \<tau> \<equiv> \<forall> t. (t\<in>RED \<tau> \<longrightarrow> SN(t))"

  "CR2" :: "ty \<Rightarrow> bool"
  "CR2 \<tau> \<equiv> \<forall>t t'. (t\<in>RED \<tau> \<and> t \<longrightarrow>\<^isub>\<beta> t') \<longrightarrow> t'\<in>RED \<tau>"

  "CR3_RED" :: "lam \<Rightarrow> ty \<Rightarrow> bool"
  "CR3_RED t \<tau> \<equiv> \<forall>t'. t\<longrightarrow>\<^isub>\<beta> t' \<longrightarrow>  t'\<in>RED \<tau>" 

  "CR3" :: "ty \<Rightarrow> bool"
  "CR3 \<tau> \<equiv> \<forall>t. (NEUT t \<and> CR3_RED t \<tau>) \<longrightarrow> t\<in>RED \<tau>"
   
  "CR4" :: "ty \<Rightarrow> bool"
  "CR4 \<tau> \<equiv> \<forall>t. (NEUT t \<and> NORMAL t) \<longrightarrow>t\<in>RED \<tau>"

lemma CR3_CR4: "CR3 \<tau> \<Longrightarrow> CR4 \<tau>"
apply(simp (no_asm_use) add: CR3_def CR3_RED_def CR4_def NORMAL_def)
apply(blast)
done

lemma sub_ind: 
  "SN(u)\<Longrightarrow>(u\<in>RED \<tau>\<longrightarrow>(\<forall>t. (NEUT t\<and>CR2 \<tau>\<and>CR3 \<sigma>\<and>CR3_RED t (\<tau>\<rightarrow>\<sigma>))\<longrightarrow>(App t u)\<in>RED \<sigma>))"
apply(simp add: SN_def)
apply(erule accp_induct)
apply(auto)
apply(simp add: CR3_def)
apply(rotate_tac 5)
apply(drule_tac x="App t x" in spec)
apply(drule mp)
apply(rule conjI)
apply(force simp only: NEUT_def)
apply(simp (no_asm) add: CR3_RED_def)
apply(clarify)
apply(ind_cases "App t x \<longrightarrow>\<^isub>\<beta> t'" for x t t')
apply(simp_all add: lam.inject)
apply(simp only:  CR3_RED_def)
apply(drule_tac x="s2" in spec)
apply(simp)
apply(drule_tac x="s2" in spec)
apply(simp)
apply(drule mp)
apply(simp (no_asm_use) add: CR2_def)
apply(blast)
apply(drule_tac x="ta" in spec)
apply(force)
apply(auto simp only: NEUT_def lam.inject lam.distinct)
done

lemma RED_props: 
  shows "CR1 \<tau>" and "CR2 \<tau>" and "CR3 \<tau>"
proof (nominal_induct \<tau> rule: ty.induct)
  case (TVar a)
  { case 1 show "CR1 (TVar a)" by (simp add: CR1_def)
  next
    case 2 show "CR2 (TVar a)" by (force intro: SN_preserved simp add: CR2_def)
  next
    case 3 show "CR3 (TVar a)" by (force intro: SN_intro simp add: CR3_def CR3_RED_def)
  }
next
  case (TArr \<tau>1 \<tau>2)
  { case 1
    have ih_CR3_\<tau>1: "CR3 \<tau>1" by fact
    have ih_CR1_\<tau>2: "CR1 \<tau>2" by fact
    show "CR1 (\<tau>1 \<rightarrow> \<tau>2)"
    proof (simp add: CR1_def, intro strip)
      fix t
      assume a: "\<forall>u. u \<in> RED \<tau>1 \<longrightarrow> App t u \<in> RED \<tau>2"
      from ih_CR3_\<tau>1 have "CR4 \<tau>1" by (simp add: CR3_CR4) 
      moreover
      have "NEUT (Var a)" by (force simp add: NEUT_def)
      moreover
      have "NORMAL (Var a)" by (rule NORMAL_Var)
      ultimately have "(Var a)\<in> RED \<tau>1" by (simp add: CR4_def)
      with a have "App t (Var a) \<in> RED \<tau>2" by simp
      hence "SN (App t (Var a))" using ih_CR1_\<tau>2 by (simp add: CR1_def)
      thus "SN(t)" by (rule qq3)
    qed
  next
    case 2
    have ih_CR1_\<tau>1: "CR1 \<tau>1" by fact
    have ih_CR2_\<tau>2: "CR2 \<tau>2" by fact
    show "CR2 (\<tau>1 \<rightarrow> \<tau>2)"
    proof (simp add: CR2_def, intro strip)
      fix t1 t2 u
      assume "(\<forall>u. u \<in> RED \<tau>1 \<longrightarrow> App t1 u \<in> RED \<tau>2) \<and>  t1 \<longrightarrow>\<^isub>\<beta> t2" 
	and  "u \<in> RED \<tau>1"
      hence "t1 \<longrightarrow>\<^isub>\<beta> t2" and "App t1 u \<in> RED \<tau>2" by simp_all
      thus "App t2 u \<in> RED \<tau>2" using ih_CR2_\<tau>2 by (force simp add: CR2_def)
    qed
  next
    case 3
    have ih_CR1_\<tau>1: "CR1 \<tau>1" by fact
    have ih_CR2_\<tau>1: "CR2 \<tau>1" by fact
    have ih_CR3_\<tau>2: "CR3 \<tau>2" by fact
    show "CR3 (\<tau>1 \<rightarrow> \<tau>2)"
    proof (simp add: CR3_def, intro strip)
      fix t u
      assume a1: "u \<in> RED \<tau>1"
      assume a2: "NEUT t \<and> CR3_RED t (\<tau>1 \<rightarrow> \<tau>2)"
      from a1 have "SN(u)" using ih_CR1_\<tau>1 by (simp add: CR1_def)
      hence "u\<in>RED \<tau>1\<longrightarrow>(\<forall>t. (NEUT t\<and>CR2 \<tau>1\<and>CR3 \<tau>2\<and>CR3_RED t (\<tau>1\<rightarrow>\<tau>2))\<longrightarrow>(App t u)\<in>RED \<tau>2)" 
	by (rule sub_ind)
      with a1 a2 show "(App t u)\<in>RED \<tau>2" using ih_CR2_\<tau>1 ih_CR3_\<tau>2 by simp
    qed
  }
qed
    
lemma double_acc_aux:
  assumes a_acc: "accp r a"
  and b_acc: "accp r b"
  and hyp: "\<And>x z.
    (\<And>y. r y x \<Longrightarrow> accp r y) \<Longrightarrow>
    (\<And>y. r y x \<Longrightarrow> P y z) \<Longrightarrow>
    (\<And>u. r u z \<Longrightarrow> accp r u) \<Longrightarrow>
    (\<And>u. r u z \<Longrightarrow> P x u) \<Longrightarrow> P x z"
  shows "P a b"
proof -
  from a_acc
  have r: "\<And>b. accp r b \<Longrightarrow> P a b"
  proof (induct a rule: accp.induct)
    case (accI x)
    note accI' = accI
    have "accp r b" by fact
    thus ?case
    proof (induct b rule: accp.induct)
      case (accI y)
      show ?case
	apply (rule hyp)
	apply (erule accI')
	apply (erule accI')
	apply (rule accp.accI)
	apply (erule accI)
	apply (erule accI)
	apply (erule accI)
	done
    qed
  qed
  from b_acc show ?thesis by (rule r)
qed

lemma double_acc:
  "\<lbrakk>accp r a; accp r b; \<forall>x z. ((\<forall>y. r y x \<longrightarrow> P y z) \<and> (\<forall>u. r u z \<longrightarrow> P x u)) \<longrightarrow> P x z\<rbrakk> \<Longrightarrow> P a b"
apply(rule_tac r="r" in double_acc_aux)
apply(assumption)+
apply(blast)
done

lemma abs_RED: "(\<forall>s\<in>RED \<tau>. t[x::=s]\<in>RED \<sigma>)\<longrightarrow>Lam [x].t\<in>RED (\<tau>\<rightarrow>\<sigma>)"
apply(simp)
apply(clarify)
apply(subgoal_tac "termip Beta t")(*1*)
apply(erule rev_mp)
apply(subgoal_tac "u \<in> RED \<tau>")(*A*)
apply(erule rev_mp)
apply(rule_tac a="t" and b="u" in double_acc)
apply(assumption)
apply(subgoal_tac "CR1 \<tau>")(*A*)
apply(simp add: CR1_def SN_def)
(*A*)
apply(force simp add: RED_props)
apply(simp)
apply(clarify)
apply(subgoal_tac "CR3 \<sigma>")(*B*)
apply(simp add: CR3_def)
apply(rotate_tac 6)
apply(drule_tac x="App(Lam[x].xa ) z" in spec)
apply(drule mp)
apply(rule conjI)
apply(force simp add: NEUT_def)
apply(simp add: CR3_RED_def)
apply(clarify)
apply(ind_cases "App(Lam[x].xa) z \<longrightarrow>\<^isub>\<beta> t'" for xa z t')
apply(auto simp add: lam.inject lam.distinct)
apply(drule beta_abs)
apply(auto)
apply(drule_tac x="t''" in spec)
apply(simp)
apply(drule mp)
apply(clarify)
apply(drule_tac x="s" in bspec)
apply(assumption)
apply(subgoal_tac "xa [ x ::= s ] \<longrightarrow>\<^isub>\<beta>  t'' [ x ::= s ]")(*B*)
apply(subgoal_tac "CR2 \<sigma>")(*C*)
apply(simp (no_asm_use) add: CR2_def)
apply(blast)
(*C*)
apply(force simp add: RED_props)
(*B*)
apply(force intro!: beta_subst)
apply(assumption)
apply(rotate_tac 3)
apply(drule_tac x="s2" in spec)
apply(subgoal_tac "s2\<in>RED \<tau>")(*D*)
apply(simp)
(*D*)
apply(subgoal_tac "CR2 \<tau>")(*E*)
apply(simp (no_asm_use) add: CR2_def)
apply(blast)
(*E*)
apply(force simp add: RED_props)
apply(simp add: alpha)
apply(erule disjE)
apply(force)
apply(auto)
apply(simp add: subst_rename)
apply(drule_tac x="z" in bspec)
apply(assumption)
(*B*)
apply(force simp add: RED_props)
(*1*)
apply(drule_tac x="Var x" in bspec)
apply(subgoal_tac "CR3 \<tau>")(*2*) 
apply(drule CR3_CR4)
apply(simp add: CR4_def)
apply(drule_tac x="Var x" in spec)
apply(drule mp)
apply(rule conjI)
apply(force simp add: NEUT_def)
apply(simp add: NORMAL_def)
apply(clarify)
apply(ind_cases "Var x \<longrightarrow>\<^isub>\<beta> t'" for t')
apply(auto simp add: lam.inject lam.distinct)
apply(force simp add: RED_props)
apply(simp add: id_subs)
apply(subgoal_tac "CR1 \<sigma>")(*3*)
apply(simp add: CR1_def SN_def)
(*3*)
apply(force simp add: RED_props)
done

abbreviation 
 mapsto :: "(name\<times>lam) list \<Rightarrow> name \<Rightarrow> lam \<Rightarrow> bool" ("_ maps _ to _" [55,55,55] 55) 
where
 "\<theta> maps x to e\<equiv> (lookup \<theta> x) = e"

abbreviation 
  closes :: "(name\<times>lam) list \<Rightarrow> (name\<times>ty) list \<Rightarrow> bool" ("_ closes _" [55,55] 55) 
where
  "\<theta> closes \<Gamma> \<equiv> \<forall>x T. ((x,T) \<in> set \<Gamma> \<longrightarrow> (\<exists>t. \<theta> maps x to t \<and> t \<in> RED T))"

lemma all_RED: 
  assumes a: "\<Gamma> \<turnstile> t : \<tau>"
  and     b: "\<theta> closes \<Gamma>"
  shows "\<theta><t> \<in> RED \<tau>"
using a b
proof(nominal_induct  avoiding: \<theta> rule: typing.strong_induct)
  case (t3 a \<Gamma> \<sigma> t \<tau> \<theta>) --"lambda case"
  have ih: "\<And>\<theta>. \<theta> closes ((a,\<sigma>)#\<Gamma>) \<Longrightarrow> \<theta><t> \<in> RED \<tau>" by fact
  have \<theta>_cond: "\<theta> closes \<Gamma>" by fact
  have fresh: "a\<sharp>\<Gamma>" "a\<sharp>\<theta>" by fact+
  from ih have "\<forall>s\<in>RED \<sigma>. ((a,s)#\<theta>)<t> \<in> RED \<tau>" 
    using fresh \<theta>_cond fresh_context by simp
  then have "\<forall>s\<in>RED \<sigma>. \<theta><t>[a::=s] \<in> RED \<tau>" 
    using fresh by (simp add: psubst_subst)
  then have "(Lam [a].(\<theta><t>)) \<in> RED (\<sigma> \<rightarrow> \<tau>)" by (simp only: abs_RED)
  then show "\<theta><(Lam [a].t)> \<in> RED (\<sigma> \<rightarrow> \<tau>)" using fresh by simp
qed auto

section {* identity substitution generated from a context \<Gamma> *}
fun
  "id" :: "(name\<times>ty) list \<Rightarrow> (name\<times>lam) list"
where
  "id []    = []"
| "id ((x,\<tau>)#\<Gamma>) = (x,Var x)#(id \<Gamma>)"

lemma id_maps:
  shows "(id \<Gamma>) maps a to (Var a)"
by (induct \<Gamma>) (auto)

lemma id_fresh:
  fixes a::"name"
  assumes a: "a\<sharp>\<Gamma>"
  shows "a\<sharp>(id \<Gamma>)"
using a
by (induct \<Gamma>)
   (auto simp add: fresh_list_nil fresh_list_cons)

lemma id_apply:  
  shows "(id \<Gamma>)<t> = t"
apply(nominal_induct t avoiding: \<Gamma> rule: lam.induct)
apply(auto simp add: id_maps id_fresh)
done

lemma id_closes:
  shows "(id \<Gamma>) closes \<Gamma>"
apply(auto)
apply(simp add: id_maps)
apply(subgoal_tac "CR3 T") --"A"
apply(drule CR3_CR4)
apply(simp add: CR4_def)
apply(drule_tac x="Var x" in spec)
apply(force simp add: NEUT_def NORMAL_Var)
--"A"
apply(rule RED_props)
done

lemma typing_implies_RED:  
  assumes a: "\<Gamma> \<turnstile> t : \<tau>"
  shows "t \<in> RED \<tau>"
proof -
  have "(id \<Gamma>)<t>\<in>RED \<tau>" 
  proof -
    have "(id \<Gamma>) closes \<Gamma>" by (rule id_closes)
    with a show ?thesis by (rule all_RED)
  qed
  thus"t \<in> RED \<tau>" by (simp add: id_apply)
qed

lemma typing_implies_SN: 
  assumes a: "\<Gamma> \<turnstile> t : \<tau>"
  shows "SN(t)"
proof -
  from a have "t \<in> RED \<tau>" by (rule typing_implies_RED)
  moreover
  have "CR1 \<tau>" by (rule RED_props)
  ultimately show "SN(t)" by (simp add: CR1_def)
qed

end