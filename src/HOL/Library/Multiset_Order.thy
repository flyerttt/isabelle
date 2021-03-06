(*  Title:      HOL/Library/Multiset_Order.thy
    Author:     Dmitriy Traytel, TU Muenchen
    Author:     Jasmin Blanchette, Inria, LORIA, MPII
*)

section \<open>More Theorems about the Multiset Order\<close>

theory Multiset_Order
imports Multiset
begin

subsubsection \<open>Alternative characterizations\<close>

context order
begin

lemma reflp_le: "reflp (op \<le>)"
  unfolding reflp_def by simp

lemma antisymP_le: "antisymP (op \<le>)"
  unfolding antisym_def by auto

lemma transp_le: "transp (op \<le>)"
  unfolding transp_def by auto

lemma irreflp_less: "irreflp (op <)"
  unfolding irreflp_def by simp

lemma antisymP_less: "antisymP (op <)"
  unfolding antisym_def by auto

lemma transp_less: "transp (op <)"
  unfolding transp_def by auto

lemmas le_trans = transp_le[unfolded transp_def, rule_format]

lemma order_mult: "class.order
  (\<lambda>M N. (M, N) \<in> mult {(x, y). x < y} \<or> M = N)
  (\<lambda>M N. (M, N) \<in> mult {(x, y). x < y})"
  (is "class.order ?le ?less")
proof -
  have irrefl: "\<And>M :: 'a multiset. \<not> ?less M M"
  proof
    fix M :: "'a multiset"
    have "trans {(x'::'a, x). x' < x}"
      by (rule transI) simp
    moreover
    assume "(M, M) \<in> mult {(x, y). x < y}"
    ultimately have "\<exists>I J K. M = I + J \<and> M = I + K
      \<and> J \<noteq> {#} \<and> (\<forall>k\<in>set_mset K. \<exists>j\<in>set_mset J. (k, j) \<in> {(x, y). x < y})"
      by (rule mult_implies_one_step)
    then obtain I J K where "M = I + J" and "M = I + K"
      and "J \<noteq> {#}" and "(\<forall>k\<in>set_mset K. \<exists>j\<in>set_mset J. (k, j) \<in> {(x, y). x < y})" by blast
    then have aux1: "K \<noteq> {#}" and aux2: "\<forall>k\<in>set_mset K. \<exists>j\<in>set_mset K. k < j" by auto
    have "finite (set_mset K)" by simp
    moreover note aux2
    ultimately have "set_mset K = {}"
      by (induct rule: finite_induct)
       (simp, metis (mono_tags) insert_absorb insert_iff insert_not_empty less_irrefl less_trans)
    with aux1 show False by simp
  qed
  have trans: "\<And>K M N :: 'a multiset. ?less K M \<Longrightarrow> ?less M N \<Longrightarrow> ?less K N"
    unfolding mult_def by (blast intro: trancl_trans)
  show "class.order ?le ?less"
    by standard (auto simp add: le_multiset_def irrefl dest: trans)
qed

text \<open>The Dershowitz--Manna ordering:\<close>

definition less_multiset\<^sub>D\<^sub>M where
  "less_multiset\<^sub>D\<^sub>M M N \<longleftrightarrow>
   (\<exists>X Y. X \<noteq> {#} \<and> X \<le># N \<and> M = (N - X) + Y \<and> (\<forall>k. k \<in># Y \<longrightarrow> (\<exists>a. a \<in># X \<and> k < a)))"


text \<open>The Huet--Oppen ordering:\<close>

definition less_multiset\<^sub>H\<^sub>O where
  "less_multiset\<^sub>H\<^sub>O M N \<longleftrightarrow> M \<noteq> N \<and> (\<forall>y. count N y < count M y \<longrightarrow> (\<exists>x. y < x \<and> count M x < count N x))"

lemma mult_imp_less_multiset\<^sub>H\<^sub>O:
  "(M, N) \<in> mult {(x, y). x < y} \<Longrightarrow> less_multiset\<^sub>H\<^sub>O M N"
proof (unfold mult_def, induct rule: trancl_induct)
  case (base P)
  then show ?case
    by (auto elim!: mult1_lessE simp add: count_eq_zero_iff less_multiset\<^sub>H\<^sub>O_def split: if_splits dest!: Suc_lessD)
next
  case (step N P)
  from step(3) have "M \<noteq> N" and
    **: "\<And>y. count N y < count M y \<Longrightarrow> (\<exists>x>y. count M x < count N x)"
    by (simp_all add: less_multiset\<^sub>H\<^sub>O_def)
  from step(2) obtain M0 a K where
    *: "P = M0 + {#a#}" "N = M0 + K" "a \<notin># K" "\<And>b. b \<in># K \<Longrightarrow> b < a"
    by (blast elim: mult1_lessE)
  from \<open>M \<noteq> N\<close> ** *(1,2,3) have "M \<noteq> P" by (force dest: *(4) split: if_splits)
  moreover
  { assume "count P a \<le> count M a"
    with \<open>a \<notin># K\<close> have "count N a < count M a" unfolding *(1,2)
      by (auto simp add: not_in_iff)
      with ** obtain z where z: "z > a" "count M z < count N z"
        by blast
      with * have "count N z \<le> count P z" 
        by (force simp add: not_in_iff)
      with z have "\<exists>z > a. count M z < count P z" by auto
  } note count_a = this
  { fix y
    assume count_y: "count P y < count M y"
    have "\<exists>x>y. count M x < count P x"
    proof (cases "y = a")
      case True
      with count_y count_a show ?thesis by auto
    next
      case False
      show ?thesis
      proof (cases "y \<in># K")
        case True
        with *(4) have "y < a" by simp
        then show ?thesis by (cases "count P a \<le> count M a") (auto dest: count_a intro: less_trans)
      next
        case False
        with \<open>y \<noteq> a\<close> have "count P y = count N y" unfolding *(1,2)
          by (simp add: not_in_iff)
        with count_y ** obtain z where z: "z > y" "count M z < count N z" by auto
        show ?thesis
        proof (cases "z \<in># K")
          case True
          with *(4) have "z < a" by simp
          with z(1) show ?thesis
            by (cases "count P a \<le> count M a") (auto dest!: count_a intro: less_trans)
        next
          case False
          with \<open>a \<notin># K\<close> have "count N z \<le> count P z" unfolding *
            by (auto simp add: not_in_iff)
          with z show ?thesis by auto
        qed
      qed
    qed
  }
  ultimately show ?case unfolding less_multiset\<^sub>H\<^sub>O_def by blast
qed

lemma less_multiset\<^sub>D\<^sub>M_imp_mult:
  "less_multiset\<^sub>D\<^sub>M M N \<Longrightarrow> (M, N) \<in> mult {(x, y). x < y}"
proof -
  assume "less_multiset\<^sub>D\<^sub>M M N"
  then obtain X Y where
    "X \<noteq> {#}" and "X \<le># N" and "M = N - X + Y" and "\<forall>k. k \<in># Y \<longrightarrow> (\<exists>a. a \<in># X \<and> k < a)"
    unfolding less_multiset\<^sub>D\<^sub>M_def by blast
  then have "(N - X + Y, N - X + X) \<in> mult {(x, y). x < y}"
    by (intro one_step_implies_mult) (auto simp: Bex_def trans_def)
  with \<open>M = N - X + Y\<close> \<open>X \<le># N\<close> show "(M, N) \<in> mult {(x, y). x < y}"
    by (metis subset_mset.diff_add)
qed

lemma less_multiset\<^sub>H\<^sub>O_imp_less_multiset\<^sub>D\<^sub>M: "less_multiset\<^sub>H\<^sub>O M N \<Longrightarrow> less_multiset\<^sub>D\<^sub>M M N"
unfolding less_multiset\<^sub>D\<^sub>M_def
proof (intro iffI exI conjI)
  assume "less_multiset\<^sub>H\<^sub>O M N"
  then obtain z where z: "count M z < count N z"
    unfolding less_multiset\<^sub>H\<^sub>O_def by (auto simp: multiset_eq_iff nat_neq_iff)
  def X \<equiv> "N - M"
  def Y \<equiv> "M - N"
  from z show "X \<noteq> {#}" unfolding X_def by (auto simp: multiset_eq_iff not_less_eq_eq Suc_le_eq)
  from z show "X \<le># N" unfolding X_def by auto
  show "M = (N - X) + Y" unfolding X_def Y_def multiset_eq_iff count_union count_diff by force
  show "\<forall>k. k \<in># Y \<longrightarrow> (\<exists>a. a \<in># X \<and> k < a)"
  proof (intro allI impI)
    fix k
    assume "k \<in># Y"
    then have "count N k < count M k" unfolding Y_def
      by (auto simp add: in_diff_count)
    with \<open>less_multiset\<^sub>H\<^sub>O M N\<close> obtain a where "k < a" and "count M a < count N a"
      unfolding less_multiset\<^sub>H\<^sub>O_def by blast
    then show "\<exists>a. a \<in># X \<and> k < a" unfolding X_def
      by (auto simp add: in_diff_count)
  qed
qed

lemma mult_less_multiset\<^sub>D\<^sub>M: "(M, N) \<in> mult {(x, y). x < y} \<longleftrightarrow> less_multiset\<^sub>D\<^sub>M M N"
  by (metis less_multiset\<^sub>D\<^sub>M_imp_mult less_multiset\<^sub>H\<^sub>O_imp_less_multiset\<^sub>D\<^sub>M mult_imp_less_multiset\<^sub>H\<^sub>O)

lemma mult_less_multiset\<^sub>H\<^sub>O: "(M, N) \<in> mult {(x, y). x < y} \<longleftrightarrow> less_multiset\<^sub>H\<^sub>O M N"
  by (metis less_multiset\<^sub>D\<^sub>M_imp_mult less_multiset\<^sub>H\<^sub>O_imp_less_multiset\<^sub>D\<^sub>M mult_imp_less_multiset\<^sub>H\<^sub>O)

lemmas mult\<^sub>D\<^sub>M = mult_less_multiset\<^sub>D\<^sub>M[unfolded less_multiset\<^sub>D\<^sub>M_def]
lemmas mult\<^sub>H\<^sub>O = mult_less_multiset\<^sub>H\<^sub>O[unfolded less_multiset\<^sub>H\<^sub>O_def]

end

context linorder
begin

lemma total_le: "total {(a :: 'a, b). a \<le> b}"
  unfolding total_on_def by auto

lemma total_less: "total {(a :: 'a, b). a < b}"
  unfolding total_on_def by auto

lemma linorder_mult: "class.linorder
  (\<lambda>M N. (M, N) \<in> mult {(x, y). x < y} \<or> M = N)
  (\<lambda>M N. (M, N) \<in> mult {(x, y). x < y})"
proof -
  interpret o: order
    "(\<lambda>M N. (M, N) \<in> mult {(x, y). x < y} \<or> M = N)"
    "(\<lambda>M N. (M, N) \<in> mult {(x, y). x < y})"
    by (rule order_mult)
  show ?thesis by unfold_locales (auto 0 3 simp: mult\<^sub>H\<^sub>O not_less_iff_gr_or_eq)
qed

end

lemma less_multiset_less_multiset\<^sub>H\<^sub>O:
  "M #\<subset># N \<longleftrightarrow> less_multiset\<^sub>H\<^sub>O M N"
  unfolding less_multiset_def mult\<^sub>H\<^sub>O less_multiset\<^sub>H\<^sub>O_def ..

lemmas less_multiset\<^sub>D\<^sub>M = mult\<^sub>D\<^sub>M[folded less_multiset_def]
lemmas less_multiset\<^sub>H\<^sub>O = mult\<^sub>H\<^sub>O[folded less_multiset_def]

lemma le_multiset\<^sub>H\<^sub>O:
  fixes M N :: "('a :: linorder) multiset"
  shows "M #\<subseteq># N \<longleftrightarrow> (\<forall>y. count N y < count M y \<longrightarrow> (\<exists>x. y < x \<and> count M x < count N x))"
  by (auto simp: le_multiset_def less_multiset\<^sub>H\<^sub>O)

lemma wf_less_multiset: "wf {(M :: ('a :: wellorder) multiset, N). M #\<subset># N}"
  unfolding less_multiset_def by (auto intro: wf_mult wf)

lemma order_multiset: "class.order
  (le_multiset :: ('a :: order) multiset \<Rightarrow> ('a :: order) multiset \<Rightarrow> bool)
  (less_multiset :: ('a :: order) multiset \<Rightarrow> ('a :: order) multiset \<Rightarrow> bool)"
  by unfold_locales

lemma linorder_multiset: "class.linorder
  (le_multiset :: ('a :: linorder) multiset \<Rightarrow> ('a :: linorder) multiset \<Rightarrow> bool)
  (less_multiset :: ('a :: linorder) multiset \<Rightarrow> ('a :: linorder) multiset \<Rightarrow> bool)"
  by unfold_locales (fastforce simp add: less_multiset\<^sub>H\<^sub>O le_multiset_def not_less_iff_gr_or_eq)

interpretation multiset_linorder: linorder
  "le_multiset :: ('a :: linorder) multiset \<Rightarrow> ('a :: linorder) multiset \<Rightarrow> bool"
  "less_multiset :: ('a :: linorder) multiset \<Rightarrow> ('a :: linorder) multiset \<Rightarrow> bool"
  by (rule linorder_multiset)

interpretation multiset_wellorder: wellorder
  "le_multiset :: ('a :: wellorder) multiset \<Rightarrow> ('a :: wellorder) multiset \<Rightarrow> bool"
  "less_multiset :: ('a :: wellorder) multiset \<Rightarrow> ('a :: wellorder) multiset \<Rightarrow> bool"
  by unfold_locales (blast intro: wf_less_multiset [unfolded wf_def, simplified, rule_format])

lemma le_multiset_total:
  fixes M N :: "('a :: linorder) multiset"
  shows "\<not> M #\<subseteq># N \<Longrightarrow> N #\<subseteq># M"
  by (metis multiset_linorder.le_cases)

lemma less_eq_imp_le_multiset:
  fixes M N :: "('a :: linorder) multiset"
  shows "M \<le># N \<Longrightarrow> M #\<subseteq># N"
  unfolding le_multiset_def less_multiset\<^sub>H\<^sub>O
  by (simp add: less_le_not_le subseteq_mset_def)

lemma less_multiset_right_total:
  fixes M :: "('a :: linorder) multiset"
  shows "M #\<subset># M + {#undefined#}"
  unfolding le_multiset_def less_multiset\<^sub>H\<^sub>O by simp

lemma le_multiset_empty_left[simp]:
  fixes M :: "('a :: linorder) multiset"
  shows "{#} #\<subseteq># M"
  by (simp add: less_eq_imp_le_multiset)

lemma le_multiset_empty_right[simp]:
  fixes M :: "('a :: linorder) multiset"
  shows "M \<noteq> {#} \<Longrightarrow> \<not> M #\<subseteq># {#}"
  by (metis le_multiset_empty_left multiset_order.antisym)

lemma less_multiset_empty_left[simp]:
  fixes M :: "('a :: linorder) multiset"
  shows "M \<noteq> {#} \<Longrightarrow> {#} #\<subset># M"
  by (simp add: less_multiset\<^sub>H\<^sub>O)

lemma less_multiset_empty_right[simp]:
  fixes M :: "('a :: linorder) multiset"
  shows "\<not> M #\<subset># {#}"
  using le_empty less_multiset\<^sub>D\<^sub>M by blast

lemma
  fixes M N :: "('a :: linorder) multiset"
  shows
    le_multiset_plus_left[simp]: "N #\<subseteq># (M + N)" and
    le_multiset_plus_right[simp]: "M #\<subseteq># (M + N)"
  using [[metis_verbose = false]] by (metis less_eq_imp_le_multiset mset_le_add_left add.commute)+

lemma
  fixes M N :: "('a :: linorder) multiset"
  shows
    less_multiset_plus_plus_left_iff[simp]: "M + N #\<subset># M' + N \<longleftrightarrow> M #\<subset># M'" and
    less_multiset_plus_plus_right_iff[simp]: "M + N #\<subset># M + N' \<longleftrightarrow> N #\<subset># N'"
  unfolding less_multiset\<^sub>H\<^sub>O by auto

lemma add_eq_self_empty_iff: "M + N = M \<longleftrightarrow> N = {#}"
  by (metis add.commute add_diff_cancel_right' monoid_add_class.add.left_neutral)

lemma
  fixes M N :: "('a :: linorder) multiset"
  shows
    less_multiset_plus_left_nonempty[simp]: "M \<noteq> {#} \<Longrightarrow> N #\<subset># M + N" and
    less_multiset_plus_right_nonempty[simp]: "N \<noteq> {#} \<Longrightarrow> M #\<subset># M + N"
  using [[metis_verbose = false]]
  by (metis add.right_neutral less_multiset_empty_left less_multiset_plus_plus_right_iff
    add.commute)+

lemma ex_gt_imp_less_multiset: "(\<exists>y :: 'a :: linorder. y \<in># N \<and> (\<forall>x. x \<in># M \<longrightarrow> x < y)) \<Longrightarrow> M #\<subset># N"
  unfolding less_multiset\<^sub>H\<^sub>O
  by (metis count_eq_zero_iff count_greater_zero_iff less_le_not_le)
  
lemma ex_gt_count_imp_less_multiset:
  "(\<forall>y :: 'a :: linorder. y \<in># M + N \<longrightarrow> y \<le> x) \<Longrightarrow> count M x < count N x \<Longrightarrow> M #\<subset># N"
  unfolding less_multiset\<^sub>H\<^sub>O
  by (metis add_gr_0 count_union mem_Collect_eq not_gr0 not_le not_less_iff_gr_or_eq set_mset_def)

lemma union_less_diff_plus: "P \<le># M \<Longrightarrow> N #\<subset># P \<Longrightarrow> M - P + N #\<subset># M"
  by (drule subset_mset.diff_add[symmetric]) (metis union_less_mono2)

end
