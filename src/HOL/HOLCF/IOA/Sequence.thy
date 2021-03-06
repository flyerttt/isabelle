(*  Title:      HOL/HOLCF/IOA/Sequence.thy
    Author:     Olaf Müller
*)

section \<open>Sequences over flat domains with lifted elements\<close>

theory Sequence
imports Seq
begin

default_sort type

type_synonym 'a Seq = "'a lift seq"

definition Consq :: "'a \<Rightarrow> 'a Seq \<rightarrow> 'a Seq"
  where "Consq a = (LAM s. Def a ## s)"

definition Filter :: "('a \<Rightarrow> bool) \<Rightarrow> 'a Seq \<rightarrow> 'a Seq"
  where "Filter P = sfilter $ (flift2 P)"

definition Map :: "('a \<Rightarrow> 'b) \<Rightarrow> 'a Seq \<rightarrow> 'b Seq"
  where "Map f = smap $ (flift2 f)"

definition Forall :: "('a \<Rightarrow> bool) \<Rightarrow> 'a Seq \<Rightarrow> bool"
  where "Forall P = sforall (flift2 P)"

definition Last :: "'a Seq \<rightarrow> 'a lift"
  where "Last = slast"

definition Dropwhile :: "('a \<Rightarrow> bool) \<Rightarrow> 'a Seq \<rightarrow> 'a Seq"
  where "Dropwhile P = sdropwhile $ (flift2 P)"

definition Takewhile :: "('a \<Rightarrow> bool) \<Rightarrow> 'a Seq \<rightarrow> 'a Seq"
  where "Takewhile P = stakewhile $ (flift2 P)"

definition Zip :: "'a Seq \<rightarrow> 'b Seq \<rightarrow> ('a * 'b) Seq"
  where "Zip =
    (fix $ (LAM h t1 t2.
      case t1 of
        nil \<Rightarrow> nil
      | x ## xs \<Rightarrow>
          (case t2 of
            nil \<Rightarrow> UU
          | y ## ys \<Rightarrow>
              (case x of
                UU \<Rightarrow> UU
              | Def a \<Rightarrow>
                  (case y of
                    UU \<Rightarrow> UU
                  | Def b \<Rightarrow> Def (a, b) ## (h $ xs $ ys))))))"

definition Flat :: "'a Seq seq \<rightarrow> 'a Seq"
  where "Flat = sflat"

definition Filter2 :: "('a \<Rightarrow> bool) \<Rightarrow> 'a Seq \<rightarrow> 'a Seq"
  where "Filter2 P =
    (fix $
      (LAM h t.
        case t of
          nil \<Rightarrow> nil
        | x ## xs \<Rightarrow>
            (case x of
              UU \<Rightarrow> UU
            | Def y \<Rightarrow> (if P y then x ## (h $ xs) else h $ xs))))"

abbreviation Consq_syn  ("(_/\<leadsto>_)" [66, 65] 65)
  where "a \<leadsto> s \<equiv> Consq a $ s"


subsection \<open>List enumeration\<close>

syntax
  "_totlist" :: "args \<Rightarrow> 'a Seq"  ("[(_)!]")
  "_partlist" :: "args \<Rightarrow> 'a Seq"  ("[(_)?]")
translations
  "[x, xs!]" \<rightleftharpoons> "x \<leadsto> [xs!]"
  "[x!]" \<rightleftharpoons> "x\<leadsto>nil"
  "[x, xs?]" \<rightleftharpoons> "x \<leadsto> [xs?]"
  "[x?]" \<rightleftharpoons> "x \<leadsto> CONST bottom"


declare andalso_and [simp]
declare andalso_or [simp]


subsection \<open>Recursive equations of operators\<close>

subsubsection \<open>Map\<close>

lemma Map_UU: "Map f $ UU = UU"
  by (simp add: Map_def)

lemma Map_nil: "Map f $ nil = nil"
  by (simp add: Map_def)

lemma Map_cons: "Map f $ (x \<leadsto> xs) = (f x) \<leadsto> Map f $ xs"
  by (simp add: Map_def Consq_def flift2_def)


subsubsection \<open>Filter\<close>

lemma Filter_UU: "Filter P $ UU = UU"
  by (simp add: Filter_def)

lemma Filter_nil: "Filter P $ nil = nil"
  by (simp add: Filter_def)

lemma Filter_cons: "Filter P $ (x \<leadsto> xs) = (if P x then x \<leadsto> (Filter P $ xs) else Filter P $ xs)"
  by (simp add: Filter_def Consq_def flift2_def If_and_if)


subsubsection \<open>Forall\<close>

lemma Forall_UU: "Forall P UU"
  by (simp add: Forall_def sforall_def)

lemma Forall_nil: "Forall P nil"
  by (simp add: Forall_def sforall_def)

lemma Forall_cons: "Forall P (x \<leadsto> xs) = (P x \<and> Forall P xs)"
  by (simp add: Forall_def sforall_def Consq_def flift2_def)


subsubsection \<open>Conc\<close>

lemma Conc_cons: "(x \<leadsto> xs) @@ y = x \<leadsto> (xs @@ y)"
  by (simp add: Consq_def)


subsubsection \<open>Takewhile\<close>

lemma Takewhile_UU: "Takewhile P $ UU = UU"
  by (simp add: Takewhile_def)

lemma Takewhile_nil: "Takewhile P $ nil = nil"
  by (simp add: Takewhile_def)

lemma Takewhile_cons:
  "Takewhile P $ (x \<leadsto> xs) = (if P x then x \<leadsto> (Takewhile P $ xs) else nil)"
  by (simp add: Takewhile_def Consq_def flift2_def If_and_if)


subsubsection \<open>DropWhile\<close>

lemma Dropwhile_UU: "Dropwhile P $ UU = UU"
  by (simp add: Dropwhile_def)

lemma Dropwhile_nil: "Dropwhile P $ nil = nil"
  by (simp add: Dropwhile_def)

lemma Dropwhile_cons: "Dropwhile P $ (x \<leadsto> xs) = (if P x then Dropwhile P $ xs else x \<leadsto> xs)"
  by (simp add: Dropwhile_def Consq_def flift2_def If_and_if)


subsubsection \<open>Last\<close>

lemma Last_UU: "Last $ UU =UU"
  by (simp add: Last_def)

lemma Last_nil: "Last $ nil =UU"
  by (simp add: Last_def)

lemma Last_cons: "Last $ (x \<leadsto> xs) = (if xs = nil then Def x else Last $ xs)"
  by (cases xs) (simp_all add: Last_def Consq_def)


subsubsection \<open>Flat\<close>

lemma Flat_UU: "Flat $ UU = UU"
  by (simp add: Flat_def)

lemma Flat_nil: "Flat $ nil = nil"
  by (simp add: Flat_def)

lemma Flat_cons: "Flat $ (x ## xs) = x @@ (Flat $ xs)"
  by (simp add: Flat_def Consq_def)


subsubsection \<open>Zip\<close>

lemma Zip_unfold:
  "Zip =
    (LAM t1 t2.
      case t1 of
        nil \<Rightarrow> nil
      | x ## xs \<Rightarrow>
          (case t2 of
            nil \<Rightarrow> UU
          | y ## ys \<Rightarrow>
              (case x of
                UU \<Rightarrow> UU
              | Def a \<Rightarrow>
                  (case y of
                    UU \<Rightarrow> UU
                  | Def b \<Rightarrow> Def (a, b) ## (Zip $ xs $ ys)))))"
  apply (rule trans)
  apply (rule fix_eq4)
  apply (rule Zip_def)
  apply (rule beta_cfun)
  apply simp
  done

lemma Zip_UU1: "Zip $ UU $ y = UU"
  apply (subst Zip_unfold)
  apply simp
  done

lemma Zip_UU2: "x \<noteq> nil \<Longrightarrow> Zip $ x $ UU = UU"
  apply (subst Zip_unfold)
  apply simp
  apply (cases x)
  apply simp_all
  done

lemma Zip_nil: "Zip $ nil $ y = nil"
  apply (subst Zip_unfold)
  apply simp
  done

lemma Zip_cons_nil: "Zip $ (x \<leadsto> xs) $ nil = UU"
  apply (subst Zip_unfold)
  apply (simp add: Consq_def)
  done

lemma Zip_cons: "Zip $ (x \<leadsto> xs) $ (y \<leadsto> ys) = (x, y) \<leadsto> Zip $ xs $ ys"
  apply (rule trans)
  apply (subst Zip_unfold)
  apply simp
  apply (simp add: Consq_def)
  done

lemmas [simp del] =
  sfilter_UU sfilter_nil sfilter_cons
  smap_UU smap_nil smap_cons
  sforall2_UU sforall2_nil sforall2_cons
  slast_UU slast_nil slast_cons
  stakewhile_UU  stakewhile_nil  stakewhile_cons
  sdropwhile_UU  sdropwhile_nil  sdropwhile_cons
  sflat_UU sflat_nil sflat_cons
  szip_UU1 szip_UU2 szip_nil szip_cons_nil szip_cons

lemmas [simp] =
  Filter_UU Filter_nil Filter_cons
  Map_UU Map_nil Map_cons
  Forall_UU Forall_nil Forall_cons
  Last_UU Last_nil Last_cons
  Conc_cons
  Takewhile_UU Takewhile_nil Takewhile_cons
  Dropwhile_UU Dropwhile_nil Dropwhile_cons
  Zip_UU1 Zip_UU2 Zip_nil Zip_cons_nil Zip_cons


subsection \<open>Cons\<close>

lemma Consq_def2: "a \<leadsto> s = Def a ## s"
  by (simp add: Consq_def)

lemma Seq_exhaust: "x = UU \<or> x = nil \<or> (\<exists>a s. x = a \<leadsto> s)"
  apply (simp add: Consq_def2)
  apply (cut_tac seq.nchotomy)
  apply (fast dest: not_Undef_is_Def [THEN iffD1])
  done

lemma Seq_cases: obtains "x = UU" | "x = nil" | a s where "x = a \<leadsto> s"
  apply (cut_tac x="x" in Seq_exhaust)
  apply (erule disjE)
  apply simp
  apply (erule disjE)
  apply simp
  apply (erule exE)+
  apply simp
  done

lemma Cons_not_UU: "a \<leadsto> s \<noteq> UU"
  apply (subst Consq_def2)
  apply simp
  done

lemma Cons_not_less_UU: "\<not> (a \<leadsto> x) \<sqsubseteq> UU"
  apply (rule notI)
  apply (drule below_antisym)
  apply simp
  apply (simp add: Cons_not_UU)
  done

lemma Cons_not_less_nil: "\<not> a \<leadsto> s \<sqsubseteq> nil"
  by (simp add: Consq_def2)

lemma Cons_not_nil: "a \<leadsto> s \<noteq> nil"
  by (simp add: Consq_def2)

lemma Cons_not_nil2: "nil \<noteq> a \<leadsto> s"
  by (simp add: Consq_def2)

lemma Cons_inject_eq: "a \<leadsto> s = b \<leadsto> t \<longleftrightarrow> a = b \<and> s = t"
  by (simp add: Consq_def2 scons_inject_eq)

lemma Cons_inject_less_eq: "a \<leadsto> s \<sqsubseteq> b \<leadsto> t \<longleftrightarrow> a = b \<and> s \<sqsubseteq> t"
  by (simp add: Consq_def2)

lemma seq_take_Cons: "seq_take (Suc n) $ (a \<leadsto> x) = a \<leadsto> (seq_take n $ x)"
  by (simp add: Consq_def)

lemmas [simp] =
  Cons_not_nil2 Cons_inject_eq Cons_inject_less_eq seq_take_Cons
  Cons_not_UU Cons_not_less_UU Cons_not_less_nil Cons_not_nil


subsection \<open>Induction\<close>

lemma Seq_induct:
  assumes "adm P"
    and "P UU"
    and "P nil"
    and "\<And>a s. P s \<Longrightarrow> P (a \<leadsto> s)"
  shows "P x"
  apply (insert assms)
  apply (erule (2) seq.induct)
  apply defined
  apply (simp add: Consq_def)
  done

lemma Seq_FinitePartial_ind:
  assumes "P UU"
    and "P nil"
    and "\<And>a s. P s \<Longrightarrow> P (a \<leadsto> s)"
  shows "seq_finite x \<longrightarrow> P x"
  apply (insert assms)
  apply (erule (1) seq_finite_ind)
  apply defined
  apply (simp add: Consq_def)
  done

lemma Seq_Finite_ind:
  assumes "Finite x"
    and "P nil"
    and "\<And>a s. Finite s \<Longrightarrow> P s \<Longrightarrow> P (a \<leadsto> s)"
  shows "P x"
  apply (insert assms)
  apply (erule (1) Finite.induct)
  apply defined
  apply (simp add: Consq_def)
  done


subsection \<open>\<open>HD\<close> and \<open>TL\<close>\<close>

lemma HD_Cons [simp]: "HD $ (x \<leadsto> y) = Def x"
  by (simp add: Consq_def)

lemma TL_Cons [simp]: "TL $ (x \<leadsto> y) = y"
  by (simp add: Consq_def)


subsection \<open>\<open>Finite\<close>, \<open>Partial\<close>, \<open>Infinite\<close>\<close>

lemma Finite_Cons [simp]: "Finite (a \<leadsto> xs) = Finite xs"
  by (simp add: Consq_def2 Finite_cons)

lemma FiniteConc_1: "Finite (x::'a Seq) \<Longrightarrow> Finite y \<longrightarrow> Finite (x @@ y)"
  apply (erule Seq_Finite_ind)
  apply simp_all
  done

lemma FiniteConc_2: "Finite (z::'a Seq) \<Longrightarrow> \<forall>x y. z = x @@ y \<longrightarrow> Finite x \<and> Finite y"
  apply (erule Seq_Finite_ind)
  text \<open>\<open>nil\<close>\<close>
  apply (intro strip)
  apply (rule_tac x="x" in Seq_cases, simp_all)
  text \<open>\<open>cons\<close>\<close>
  apply (intro strip)
  apply (rule_tac x="x" in Seq_cases, simp_all)
  apply (rule_tac x="y" in Seq_cases, simp_all)
  done

lemma FiniteConc [simp]: "Finite (x @@ y) \<longleftrightarrow> Finite (x::'a Seq) \<and> Finite y"
  apply (rule iffI)
  apply (erule FiniteConc_2 [rule_format])
  apply (rule refl)
  apply (rule FiniteConc_1 [rule_format])
  apply auto
  done


lemma FiniteMap1: "Finite s \<Longrightarrow> Finite (Map f $ s)"
  apply (erule Seq_Finite_ind)
  apply simp_all
  done

lemma FiniteMap2: "Finite s \<Longrightarrow> \<forall>t. s = Map f $ t \<longrightarrow> Finite t"
  apply (erule Seq_Finite_ind)
  apply (intro strip)
  apply (rule_tac x="t" in Seq_cases, simp_all)
  text \<open>\<open>main case\<close>\<close>
  apply auto
  apply (rule_tac x="t" in Seq_cases, simp_all)
  done

lemma Map2Finite: "Finite (Map f $ s) = Finite s"
  apply auto
  apply (erule FiniteMap2 [rule_format])
  apply (rule refl)
  apply (erule FiniteMap1)
  done


lemma FiniteFilter: "Finite s \<Longrightarrow> Finite (Filter P $ s)"
  apply (erule Seq_Finite_ind)
  apply simp_all
  done


subsection \<open>\<open>Conc\<close>\<close>

lemma Conc_cong: "\<And>x::'a Seq. Finite x \<Longrightarrow> (x @@ y) = (x @@ z) \<longleftrightarrow> y = z"
  apply (erule Seq_Finite_ind)
  apply simp_all
  done

lemma Conc_assoc: "(x @@ y) @@ z = (x::'a Seq) @@ y @@ z"
  apply (rule_tac x="x" in Seq_induct)
  apply simp_all
  done

lemma nilConc [simp]: "s@@ nil = s"
  apply (induct s)
  apply simp
  apply simp
  apply simp
  apply simp
  done


(*Should be same as nil_is_Conc2 when all nils are turned to right side!*)
lemma nil_is_Conc: "nil = x @@ y \<longleftrightarrow> (x::'a Seq) = nil \<and> y = nil"
  apply (rule_tac x="x" in Seq_cases)
  apply auto
  done

lemma nil_is_Conc2: "x @@ y = nil \<longleftrightarrow> (x::'a Seq) = nil \<and> y = nil"
  apply (rule_tac x="x" in Seq_cases)
  apply auto
  done


subsection \<open>Last\<close>

lemma Finite_Last1: "Finite s \<Longrightarrow> s \<noteq> nil \<longrightarrow> Last $ s \<noteq> UU"
  by (erule Seq_Finite_ind) simp_all

lemma Finite_Last2: "Finite s \<Longrightarrow> Last $ s = UU \<longrightarrow> s = nil"
  by (erule Seq_Finite_ind) auto


subsection \<open>Filter, Conc\<close>

lemma FilterPQ: "Filter P $ (Filter Q $ s) = Filter (\<lambda>x. P x \<and> Q x) $ s"
  by (rule_tac x="s" in Seq_induct) simp_all

lemma FilterConc: "Filter P $ (x @@ y) = (Filter P $ x @@ Filter P $ y)"
  by (simp add: Filter_def sfiltersconc)


subsection \<open>Map\<close>

lemma MapMap: "Map f $ (Map g $ s) = Map (f \<circ> g) $ s"
  by (rule_tac x="s" in Seq_induct) simp_all

lemma MapConc: "Map f $ (x @@ y) = (Map f $ x) @@ (Map f $ y)"
  by (rule_tac x="x" in Seq_induct) simp_all

lemma MapFilter: "Filter P $ (Map f $ x) = Map f $ (Filter (P \<circ> f) $ x)"
  by (rule_tac x="x" in Seq_induct) simp_all

lemma nilMap: "nil = (Map f $ s) \<longrightarrow> s = nil"
  by (rule_tac x="s" in Seq_cases) simp_all

lemma ForallMap: "Forall P (Map f $ s) = Forall (P \<circ> f) s"
  apply (rule_tac x="s" in Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  done


subsection \<open>Forall\<close>

lemma ForallPForallQ1: "Forall P ys \<and> (\<forall>x. P x \<longrightarrow> Q x) \<longrightarrow> Forall Q ys"
  apply (rule_tac x="ys" in Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  done

lemmas ForallPForallQ =
  ForallPForallQ1 [THEN mp, OF conjI, OF _ allI, OF _ impI]

lemma Forall_Conc_impl: "Forall P x \<and> Forall P y \<longrightarrow> Forall P (x @@ y)"
  apply (rule_tac x="x" in Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  done

lemma Forall_Conc [simp]: "Finite x \<Longrightarrow> Forall P (x @@ y) \<longleftrightarrow> Forall P x \<and> Forall P y"
  by (erule Seq_Finite_ind) simp_all

lemma ForallTL1: "Forall P s \<longrightarrow> Forall P (TL $ s)"
  apply (rule_tac x="s" in Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  done

lemmas ForallTL = ForallTL1 [THEN mp]

lemma ForallDropwhile1: "Forall P s \<longrightarrow> Forall P (Dropwhile Q $ s)"
  apply (rule_tac x="s" in Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  done

lemmas ForallDropwhile = ForallDropwhile1 [THEN mp]


(*only admissible in t, not if done in s*)
lemma Forall_prefix: "\<forall>s. Forall P s \<longrightarrow> t \<sqsubseteq> s \<longrightarrow> Forall P t"
  apply (rule_tac x="t" in Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  apply (intro strip)
  apply (rule_tac x="sa" in Seq_cases)
  apply simp
  apply auto
  done

lemmas Forall_prefixclosed = Forall_prefix [rule_format]

lemma Forall_postfixclosed: "Finite h \<Longrightarrow> Forall P s \<Longrightarrow> s= h @@ t \<Longrightarrow> Forall P t"
  by auto


lemma ForallPFilterQR1:
  "(\<forall>x. P x \<longrightarrow> Q x = R x) \<and> Forall P tr \<longrightarrow> Filter Q $ tr = Filter R $ tr"
  apply (rule_tac x="tr" in Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  done

lemmas ForallPFilterQR = ForallPFilterQR1 [THEN mp, OF conjI, OF allI]


subsection \<open>Forall, Filter\<close>

lemma ForallPFilterP: "Forall P (Filter P $ x)"
  by (simp add: Filter_def Forall_def forallPsfilterP)

(*holds also in other direction, then equal to forallPfilterP*)
lemma ForallPFilterPid1: "Forall P x \<longrightarrow> Filter P $ x = x"
  apply (rule_tac x="x" in Seq_induct)
  apply (simp add: Forall_def sforall_def Filter_def)
  apply simp_all
  done

lemmas ForallPFilterPid = ForallPFilterPid1 [THEN mp]

(*holds also in other direction*)
lemma ForallnPFilterPnil1: "Finite ys \<Longrightarrow> Forall (\<lambda>x. \<not> P x) ys \<longrightarrow> Filter P $ ys = nil"
  by (erule Seq_Finite_ind) simp_all

lemmas ForallnPFilterPnil = ForallnPFilterPnil1 [THEN mp]


(*holds also in other direction*)
lemma ForallnPFilterPUU1: "\<not> Finite ys \<and> Forall (\<lambda>x. \<not> P x) ys \<longrightarrow> Filter P $ ys = UU"
  apply (rule_tac x="ys" in Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  done

lemmas ForallnPFilterPUU = ForallnPFilterPUU1 [THEN mp, OF conjI]


(*inverse of ForallnPFilterPnil*)
lemma FilternPnilForallP [rule_format]: "Filter P $ ys = nil \<longrightarrow> Forall (\<lambda>x. \<not> P x) ys \<and> Finite ys"
  apply (rule_tac x="ys" in Seq_induct)
  text \<open>adm\<close>
  apply (simp add: Forall_def sforall_def)
  text \<open>base cases\<close>
  apply simp
  apply simp
  text \<open>main case\<close>
  apply simp
  done

(*inverse of ForallnPFilterPUU*)
lemma FilternPUUForallP:
  assumes "Filter P $ ys = UU"
  shows "Forall (\<lambda>x. \<not> P x) ys \<and> \<not> Finite ys"
proof
  show "Forall (\<lambda>x. \<not> P x) ys"
  proof (rule classical)
    assume "\<not> ?thesis"
    then have "Filter P $ ys \<noteq> UU"
      apply (rule rev_mp)
      apply (induct ys rule: Seq_induct)
      apply (simp add: Forall_def sforall_def)
      apply simp_all
      done
    with assms show ?thesis by contradiction
  qed
  show "\<not> Finite ys"
  proof
    assume "Finite ys"
    then have "Filter P$ys \<noteq> UU"
      by (rule Seq_Finite_ind) simp_all
    with assms show False by contradiction
  qed
qed


lemma ForallQFilterPnil:
  "Forall Q ys \<Longrightarrow> Finite ys \<Longrightarrow> (\<And>x. Q x \<Longrightarrow> \<not> P x) \<Longrightarrow> Filter P $ ys = nil"
  apply (erule ForallnPFilterPnil)
  apply (erule ForallPForallQ)
  apply auto
  done

lemma ForallQFilterPUU: "\<not> Finite ys \<Longrightarrow> Forall Q ys \<Longrightarrow> (\<And>x. Q x \<Longrightarrow> \<not> P x) \<Longrightarrow> Filter P $ ys = UU"
  apply (erule ForallnPFilterPUU)
  apply (erule ForallPForallQ)
  apply auto
  done


subsection \<open>Takewhile, Forall, Filter\<close>

lemma ForallPTakewhileP [simp]: "Forall P (Takewhile P $ x)"
  by (simp add: Forall_def Takewhile_def sforallPstakewhileP)


lemma ForallPTakewhileQ [simp]: "(\<And>x. Q x \<Longrightarrow> P x) \<Longrightarrow> Forall P (Takewhile Q $ x)"
  apply (rule ForallPForallQ)
  apply (rule ForallPTakewhileP)
  apply auto
  done


lemma FilterPTakewhileQnil [simp]:
  "Finite (Takewhile Q $ ys) \<Longrightarrow> (\<And>x. Q x \<Longrightarrow> \<not> P x) \<Longrightarrow> Filter P $ (Takewhile Q $ ys) = nil"
  apply (erule ForallnPFilterPnil)
  apply (rule ForallPForallQ)
  apply (rule ForallPTakewhileP)
  apply auto
  done

lemma FilterPTakewhileQid [simp]:
  "(\<And>x. Q x \<Longrightarrow> P x) \<Longrightarrow> Filter P $ (Takewhile Q $ ys) = Takewhile Q $ ys"
  apply (rule ForallPFilterPid)
  apply (rule ForallPForallQ)
  apply (rule ForallPTakewhileP)
  apply auto
  done


lemma Takewhile_idempotent: "Takewhile P $ (Takewhile P $ s) = Takewhile P $ s"
  apply (rule_tac x="s" in Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  done

lemma ForallPTakewhileQnP [simp]:
  "Forall P s \<longrightarrow> Takewhile (\<lambda>x. Q x \<or> (\<not> P x)) $ s = Takewhile Q $ s"
  apply (rule_tac x="s" in Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  done

lemma ForallPDropwhileQnP [simp]:
  "Forall P s \<longrightarrow> Dropwhile (\<lambda>x. Q x \<or> (\<not> P x)) $ s = Dropwhile Q $ s"
  apply (rule_tac x="s" in Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  done


lemma TakewhileConc1: "Forall P s \<longrightarrow> Takewhile P $ (s @@ t) = s @@ (Takewhile P $ t)"
  apply (rule_tac x="s" in Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  done

lemmas TakewhileConc = TakewhileConc1 [THEN mp]

lemma DropwhileConc1: "Finite s \<Longrightarrow> Forall P s \<longrightarrow> Dropwhile P $ (s @@ t) = Dropwhile P $ t"
  by (erule Seq_Finite_ind) simp_all

lemmas DropwhileConc = DropwhileConc1 [THEN mp]


subsection \<open>Coinductive characterizations of Filter\<close>

lemma divide_Seq_lemma:
  "HD $ (Filter P $ y) = Def x \<longrightarrow>
    y = (Takewhile (\<lambda>x. \<not> P x) $ y) @@ (x \<leadsto> TL $ (Dropwhile (\<lambda>a. \<not> P a) $ y)) \<and>
    Finite (Takewhile (\<lambda>x. \<not> P x) $ y) \<and> P x"
  (* FIX: pay attention: is only admissible with chain-finite package to be added to
          adm test and Finite f x admissibility *)
  apply (rule_tac x="y" in Seq_induct)
  apply (simp add: adm_subst [OF _ adm_Finite])
  apply simp
  apply simp
  apply (case_tac "P a")
   apply simp
   apply blast
  text \<open>\<open>\<not> P a\<close>\<close>
  apply simp
  done

lemma divide_Seq: "(x \<leadsto> xs) \<sqsubseteq> Filter P $ y \<Longrightarrow>
  y = ((Takewhile (\<lambda>a. \<not> P a) $ y) @@ (x \<leadsto> TL $ (Dropwhile (\<lambda>a. \<not> P a) $ y))) \<and>
  Finite (Takewhile (\<lambda>a. \<not> P a) $ y) \<and> P x"
  apply (rule divide_Seq_lemma [THEN mp])
  apply (drule_tac f="HD" and x="x \<leadsto> xs" in  monofun_cfun_arg)
  apply simp
  done


lemma nForall_HDFilter: "\<not> Forall P y \<longrightarrow> (\<exists>x. HD $ (Filter (\<lambda>a. \<not> P a) $ y) = Def x)"
  unfolding not_Undef_is_Def [symmetric]
  apply (induct y rule: Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  done


lemma divide_Seq2:
  "\<not> Forall P y \<Longrightarrow>
    \<exists>x. y = Takewhile P$y @@ (x \<leadsto> TL $ (Dropwhile P $ y)) \<and> Finite (Takewhile P $ y) \<and> \<not> P x"
  apply (drule nForall_HDFilter [THEN mp])
  apply safe
  apply (rule_tac x="x" in exI)
  apply (cut_tac P1="\<lambda>x. \<not> P x" in divide_Seq_lemma [THEN mp])
  apply auto
  done


lemma divide_Seq3:
  "\<not> Forall P y \<Longrightarrow> \<exists>x bs rs. y = (bs @@ (x\<leadsto>rs)) \<and> Finite bs \<and> Forall P bs \<and> \<not> P x"
  apply (drule divide_Seq2)
  apply fastforce
  done

lemmas [simp] = FilterPQ FilterConc Conc_cong


subsection \<open>Take-lemma\<close>

lemma seq_take_lemma: "(\<forall>n. seq_take n $ x = seq_take n $ x') \<longleftrightarrow> x = x'"
  apply (rule iffI)
  apply (rule seq.take_lemma)
  apply auto
  done

lemma take_reduction1:
  "\<forall>n. ((\<forall>k. k < n \<longrightarrow> seq_take k $ y1 = seq_take k $ y2) \<longrightarrow>
    seq_take n $ (x @@ (t \<leadsto> y1)) =  seq_take n $ (x @@ (t \<leadsto> y2)))"
  apply (rule_tac x="x" in Seq_induct)
  apply simp_all
  apply (intro strip)
  apply (case_tac "n")
  apply auto
  apply (case_tac "n")
  apply auto
  done

lemma take_reduction:
  "x = y \<Longrightarrow> s = t \<Longrightarrow> (\<And>k. k < n \<Longrightarrow> seq_take k $ y1 = seq_take k $ y2)
    \<Longrightarrow> seq_take n $ (x @@ (s \<leadsto> y1)) = seq_take n $ (y @@ (t \<leadsto> y2))"
  by (auto intro!: take_reduction1 [rule_format])


text \<open>
  Take-lemma and take-reduction for \<open>\<sqsubseteq>\<close> instead of \<open>=\<close>.
\<close>
          
lemma take_reduction_less1:
  "\<forall>n. ((\<forall>k. k < n \<longrightarrow> seq_take k $ y1 \<sqsubseteq> seq_take k$y2) \<longrightarrow>
    seq_take n $ (x @@ (t \<leadsto> y1)) \<sqsubseteq> seq_take n $ (x @@ (t \<leadsto> y2)))"
  apply (rule_tac x="x" in Seq_induct)
  apply simp_all
  apply (intro strip)
  apply (case_tac "n")
  apply auto
  apply (case_tac "n")
  apply auto
  done

lemma take_reduction_less:
  "x = y \<Longrightarrow> s = t \<Longrightarrow> (\<And>k. k < n \<Longrightarrow> seq_take k $ y1 \<sqsubseteq> seq_take k $ y2) \<Longrightarrow>
    seq_take n $ (x @@ (s \<leadsto> y1)) \<sqsubseteq> seq_take n $ (y @@ (t \<leadsto> y2))"
  by (auto intro!: take_reduction_less1 [rule_format])

lemma take_lemma_less1:
  assumes "\<And>n. seq_take n $ s1 \<sqsubseteq> seq_take n $ s2"
  shows "s1 \<sqsubseteq> s2"
  apply (rule_tac t="s1" in seq.reach [THEN subst])
  apply (rule_tac t="s2" in seq.reach [THEN subst])
  apply (rule lub_mono)
  apply (rule seq.chain_take [THEN ch2ch_Rep_cfunL])
  apply (rule seq.chain_take [THEN ch2ch_Rep_cfunL])
  apply (rule assms)
  done

lemma take_lemma_less: "(\<forall>n. seq_take n $ x \<sqsubseteq> seq_take n $ x') \<longleftrightarrow> x \<sqsubseteq> x'"
  apply (rule iffI)
  apply (rule take_lemma_less1)
  apply auto
  apply (erule monofun_cfun_arg)
  done


text \<open>Take-lemma proof principles.\<close>

lemma take_lemma_principle1:
  assumes "\<And>s. Forall Q s \<Longrightarrow> A s \<Longrightarrow> f s = g s"
    and "\<And>s1 s2 y. Forall Q s1 \<Longrightarrow> Finite s1 \<Longrightarrow>
      \<not> Q y \<Longrightarrow> A (s1 @@ y \<leadsto> s2) \<Longrightarrow> f (s1 @@ y \<leadsto> s2) = g (s1 @@ y \<leadsto> s2)"
  shows "A x \<longrightarrow> f x = g x"
  using assms by (cases "Forall Q x") (auto dest!: divide_Seq3)

lemma take_lemma_principle2:
  assumes "\<And>s. Forall Q s \<Longrightarrow> A s \<Longrightarrow> f s = g s"
    and "\<And>s1 s2 y. Forall Q s1 \<Longrightarrow> Finite s1 \<Longrightarrow> \<not> Q y \<Longrightarrow> A (s1 @@ y \<leadsto> s2) \<Longrightarrow>
      \<forall>n. seq_take n $ (f (s1 @@ y \<leadsto> s2)) = seq_take n $ (g (s1 @@ y \<leadsto> s2))"
  shows "A x \<longrightarrow> f x = g x"
  using assms
  apply (cases "Forall Q x")
  apply (auto dest!: divide_Seq3)
  apply (rule seq.take_lemma)
  apply auto
  done


text \<open>
  Note: in the following proofs the ordering of proof steps is very important,
  as otherwise either \<open>Forall Q s1\<close> would be in the IH as assumption (then
  rule useless) or it is not possible to strengthen the IH apply doing a
  forall closure of the sequence \<open>t\<close> (then rule also useless). This is also
  the reason why the induction rule (\<open>nat_less_induct\<close> or \<open>nat_induct\<close>) has to
  to be imbuilt into the rule, as induction has to be done early and the take
  lemma has to be used in the trivial direction afterwards for the
  \<open>Forall Q x\<close> case.
\<close>

lemma take_lemma_induct:
  assumes "\<And>s. Forall Q s \<Longrightarrow> A s \<Longrightarrow> f s = g s"
    and "\<And>s1 s2 y n.
      \<forall>t. A t \<longrightarrow> seq_take n $ (f t) = seq_take n $ (g t) \<Longrightarrow>
      Forall Q s1 \<Longrightarrow> Finite s1 \<Longrightarrow> \<not> Q y \<Longrightarrow> A (s1 @@ y \<leadsto> s2) \<Longrightarrow>
      seq_take (Suc n) $ (f (s1 @@ y \<leadsto> s2)) =
      seq_take (Suc n) $ (g (s1 @@ y \<leadsto> s2))"
  shows "A x \<longrightarrow> f x = g x"
  apply (insert assms)
  apply (rule impI)
  apply (rule seq.take_lemma)
  apply (rule mp)
  prefer 2 apply assumption
  apply (rule_tac x="x" in spec)
  apply (rule nat.induct)
  apply simp
  apply (rule allI)
  apply (case_tac "Forall Q xa")
  apply (force intro!: seq_take_lemma [THEN iffD2, THEN spec])
  apply (auto dest!: divide_Seq3)
  done


lemma take_lemma_less_induct:
  assumes "\<And>s. Forall Q s \<Longrightarrow> A s \<Longrightarrow> f s = g s"
    and "\<And>s1 s2 y n.
      \<forall>t m. m < n \<longrightarrow> A t \<longrightarrow> seq_take m $ (f t) = seq_take m $ (g t) \<Longrightarrow>
      Forall Q s1 \<Longrightarrow> Finite s1 \<Longrightarrow> \<not> Q y \<Longrightarrow> A (s1 @@ y \<leadsto> s2) \<Longrightarrow>
      seq_take n $ (f (s1 @@ y \<leadsto> s2)) =
      seq_take n $ (g (s1 @@ y \<leadsto> s2))"
  shows "A x \<longrightarrow> f x = g x"
  apply (insert assms)
  apply (rule impI)
  apply (rule seq.take_lemma)
  apply (rule mp)
  prefer 2 apply assumption
  apply (rule_tac x="x" in spec)
  apply (rule nat_less_induct)
  apply (rule allI)
  apply (case_tac "Forall Q xa")
  apply (force intro!: seq_take_lemma [THEN iffD2, THEN spec])
  apply (auto dest!: divide_Seq3)
  done



lemma take_lemma_in_eq_out:
  assumes "A UU \<Longrightarrow> f UU = g UU"
    and "A nil \<Longrightarrow> f nil = g nil"
    and "\<And>s y n.
      \<forall>t. A t \<longrightarrow> seq_take n $ (f t) = seq_take n $ (g t) \<Longrightarrow> A (y \<leadsto> s) \<Longrightarrow>
      seq_take (Suc n) $ (f (y \<leadsto> s)) =
      seq_take (Suc n) $ (g (y \<leadsto> s))"
  shows "A x \<longrightarrow> f x = g x"
  apply (insert assms)
  apply (rule impI)
  apply (rule seq.take_lemma)
  apply (rule mp)
  prefer 2 apply assumption
  apply (rule_tac x="x" in spec)
  apply (rule nat.induct)
  apply simp
  apply (rule allI)
  apply (rule_tac x="xa" in Seq_cases)
  apply simp_all
  done


subsection \<open>Alternative take_lemma proofs\<close>

subsubsection \<open>Alternative Proof of FilterPQ\<close>

declare FilterPQ [simp del]


(*In general: How to do this case without the same adm problems
  as for the entire proof?*)
lemma Filter_lemma1:
  "Forall (\<lambda>x. \<not> (P x \<and> Q x)) s \<longrightarrow>
    Filter P $ (Filter Q $ s) = Filter (\<lambda>x. P x \<and> Q x) $ s"
  apply (rule_tac x="s" in Seq_induct)
  apply (simp add: Forall_def sforall_def)
  apply simp_all
  done

lemma Filter_lemma2: "Finite s \<Longrightarrow>
  Forall (\<lambda>x. \<not> P x \<or> \<not> Q x) s \<longrightarrow> Filter P $ (Filter Q $ s) = nil"
  by (erule Seq_Finite_ind) simp_all

lemma Filter_lemma3: "Finite s \<Longrightarrow>
  Forall (\<lambda>x. \<not> P x \<or> \<not> Q x) s \<longrightarrow> Filter (\<lambda>x. P x \<and> Q x) $ s = nil"
  by (erule Seq_Finite_ind) simp_all

lemma FilterPQ_takelemma: "Filter P $ (Filter Q $ s) = Filter (\<lambda>x. P x \<and> Q x) $ s"
  apply (rule_tac A1="\<lambda>x. True" and Q1="\<lambda>x. \<not> (P x \<and> Q x)" and x1="s" in
    take_lemma_induct [THEN mp])
  (*better support for A = \<lambda>x. True*)
  apply (simp add: Filter_lemma1)
  apply (simp add: Filter_lemma2 Filter_lemma3)
  apply simp
  done

declare FilterPQ [simp]


subsubsection \<open>Alternative Proof of \<open>MapConc\<close>\<close>

lemma MapConc_takelemma: "Map f $ (x @@ y) = (Map f $ x) @@ (Map f $ y)"
  apply (rule_tac A1="\<lambda>x. True" and x1="x" in take_lemma_in_eq_out [THEN mp])
  apply auto
  done

ML \<open>
fun Seq_case_tac ctxt s i =
  Rule_Insts.res_inst_tac ctxt [((("x", 0), Position.none), s)] [] @{thm Seq_cases} i
  THEN hyp_subst_tac ctxt i THEN hyp_subst_tac ctxt (i + 1) THEN hyp_subst_tac ctxt (i + 2);

(* on a\<leadsto>s only simp_tac, as full_simp_tac is uncomplete and often causes errors *)
fun Seq_case_simp_tac ctxt s i =
  Seq_case_tac ctxt s i
  THEN asm_simp_tac ctxt (i + 2)
  THEN asm_full_simp_tac ctxt (i + 1)
  THEN asm_full_simp_tac ctxt i;

(* rws are definitions to be unfolded for admissibility check *)
fun Seq_induct_tac ctxt s rws i =
  Rule_Insts.res_inst_tac ctxt [((("x", 0), Position.none), s)] [] @{thm Seq_induct} i
  THEN (REPEAT_DETERM (CHANGED (asm_simp_tac ctxt (i + 1))))
  THEN simp_tac (ctxt addsimps rws) i;

fun Seq_Finite_induct_tac ctxt i =
  eresolve_tac ctxt @{thms Seq_Finite_ind} i
  THEN (REPEAT_DETERM (CHANGED (asm_simp_tac ctxt i)));

fun pair_tac ctxt s =
  Rule_Insts.res_inst_tac ctxt [((("y", 0), Position.none), s)] [] @{thm prod.exhaust}
  THEN' hyp_subst_tac ctxt THEN' asm_full_simp_tac ctxt;

(* induction on a sequence of pairs with pairsplitting and simplification *)
fun pair_induct_tac ctxt s rws i =
  Rule_Insts.res_inst_tac ctxt [((("x", 0), Position.none), s)] [] @{thm Seq_induct} i
  THEN pair_tac ctxt "a" (i + 3)
  THEN (REPEAT_DETERM (CHANGED (simp_tac ctxt (i + 1))))
  THEN simp_tac (ctxt addsimps rws) i;
\<close>

method_setup Seq_case =
  \<open>Scan.lift Args.name >> (fn s => fn ctxt => SIMPLE_METHOD' (Seq_case_tac ctxt s))\<close>

method_setup Seq_case_simp =
  \<open>Scan.lift Args.name >> (fn s => fn ctxt => SIMPLE_METHOD' (Seq_case_simp_tac ctxt s))\<close>

method_setup Seq_induct =
  \<open>Scan.lift Args.name --
    Scan.optional ((Scan.lift (Args.$$$ "simp" -- Args.colon) |-- Attrib.thms)) []
    >> (fn (s, rws) => fn ctxt => SIMPLE_METHOD' (Seq_induct_tac ctxt s rws))\<close>

method_setup Seq_Finite_induct =
  \<open>Scan.succeed (SIMPLE_METHOD' o Seq_Finite_induct_tac)\<close>

method_setup pair =
  \<open>Scan.lift Args.name >> (fn s => fn ctxt => SIMPLE_METHOD' (pair_tac ctxt s))\<close>

method_setup pair_induct =
  \<open>Scan.lift Args.name --
    Scan.optional ((Scan.lift (Args.$$$ "simp" -- Args.colon) |-- Attrib.thms)) []
    >> (fn (s, rws) => fn ctxt => SIMPLE_METHOD' (pair_induct_tac ctxt s rws))\<close>

lemma Mapnil: "Map f $ s = nil \<longleftrightarrow> s = nil"
  by (Seq_case_simp s)

lemma MapUU: "Map f $ s = UU \<longleftrightarrow> s = UU"
  by (Seq_case_simp s)

lemma MapTL: "Map f $ (TL $ s) = TL $ (Map f $ s)"
  by (Seq_induct s)

end
