(*  Title:      HOL/Auth/OtwayRees.thy
    Author:     Lawrence C Paulson, Cambridge University Computer Laboratory
    Copyright   1996  University of Cambridge
*)

section\<open>The Original Otway-Rees Protocol\<close>

theory OtwayRees imports Public begin

text\<open>From page 244 of
  Burrows, Abadi and Needham (1989).  A Logic of Authentication.
  Proc. Royal Soc. 426

This is the original version, which encrypts Nonce NB.\<close>

inductive_set otway :: "event list set"
  where
         (*Initial trace is empty*)
   Nil:  "[] \<in> otway"

         (*The spy MAY say anything he CAN say.  We do not expect him to
           invent new nonces here, but he can also use NS1.  Common to
           all similar protocols.*)
 | Fake: "[| evsf \<in> otway;  X \<in> synth (analz (knows Spy evsf)) |]
          ==> Says Spy B X  # evsf \<in> otway"

         (*A message that has been sent can be received by the
           intended recipient.*)
 | Reception: "[| evsr \<in> otway;  Says A B X \<in>set evsr |]
               ==> Gets B X # evsr \<in> otway"

         (*Alice initiates a protocol run*)
 | OR1:  "[| evs1 \<in> otway;  Nonce NA \<notin> used evs1 |]
          ==> Says A B \<lbrace>Nonce NA, Agent A, Agent B,
                         Crypt (shrK A) \<lbrace>Nonce NA, Agent A, Agent B\<rbrace> \<rbrace>
                 # evs1 : otway"

         (*Bob's response to Alice's message.  Note that NB is encrypted.*)
 | OR2:  "[| evs2 \<in> otway;  Nonce NB \<notin> used evs2;
             Gets B \<lbrace>Nonce NA, Agent A, Agent B, X\<rbrace> : set evs2 |]
          ==> Says B Server
                  \<lbrace>Nonce NA, Agent A, Agent B, X,
                    Crypt (shrK B)
                      \<lbrace>Nonce NA, Nonce NB, Agent A, Agent B\<rbrace>\<rbrace>
                 # evs2 : otway"

         (*The Server receives Bob's message and checks that the three NAs
           match.  Then he sends a new session key to Bob with a packet for
           forwarding to Alice.*)
 | OR3:  "[| evs3 \<in> otway;  Key KAB \<notin> used evs3;
             Gets Server
                  \<lbrace>Nonce NA, Agent A, Agent B,
                    Crypt (shrK A) \<lbrace>Nonce NA, Agent A, Agent B\<rbrace>,
                    Crypt (shrK B) \<lbrace>Nonce NA, Nonce NB, Agent A, Agent B\<rbrace>\<rbrace>
               : set evs3 |]
          ==> Says Server B
                  \<lbrace>Nonce NA,
                    Crypt (shrK A) \<lbrace>Nonce NA, Key KAB\<rbrace>,
                    Crypt (shrK B) \<lbrace>Nonce NB, Key KAB\<rbrace>\<rbrace>
                 # evs3 : otway"

         (*Bob receives the Server's (?) message and compares the Nonces with
           those in the message he previously sent the Server.
           Need B \<noteq> Server because we allow messages to self.*)
 | OR4:  "[| evs4 \<in> otway;  B \<noteq> Server;
             Says B Server \<lbrace>Nonce NA, Agent A, Agent B, X',
                             Crypt (shrK B)
                                   \<lbrace>Nonce NA, Nonce NB, Agent A, Agent B\<rbrace>\<rbrace>
               : set evs4;
             Gets B \<lbrace>Nonce NA, X, Crypt (shrK B) \<lbrace>Nonce NB, Key K\<rbrace>\<rbrace>
               : set evs4 |]
          ==> Says B A \<lbrace>Nonce NA, X\<rbrace> # evs4 : otway"

         (*This message models possible leaks of session keys.  The nonces
           identify the protocol run.*)
 | Oops: "[| evso \<in> otway;
             Says Server B \<lbrace>Nonce NA, X, Crypt (shrK B) \<lbrace>Nonce NB, Key K\<rbrace>\<rbrace>
               : set evso |]
          ==> Notes Spy \<lbrace>Nonce NA, Nonce NB, Key K\<rbrace> # evso : otway"


declare Says_imp_analz_Spy [dest]
declare parts.Body  [dest]
declare analz_into_parts [dest]
declare Fake_parts_insert_in_Un  [dest]


text\<open>A "possibility property": there are traces that reach the end\<close>
lemma "[| B \<noteq> Server; Key K \<notin> used [] |]
      ==> \<exists>evs \<in> otway.
             Says B A \<lbrace>Nonce NA, Crypt (shrK A) \<lbrace>Nonce NA, Key K\<rbrace>\<rbrace>
               \<in> set evs"
apply (intro exI bexI)
apply (rule_tac [2] otway.Nil
                    [THEN otway.OR1, THEN otway.Reception,
                     THEN otway.OR2, THEN otway.Reception,
                     THEN otway.OR3, THEN otway.Reception, THEN otway.OR4]) 
apply (possibility, simp add: used_Cons) 
done

lemma Gets_imp_Says [dest!]:
     "[| Gets B X \<in> set evs; evs \<in> otway |] ==> \<exists>A. Says A B X \<in> set evs"
apply (erule rev_mp)
apply (erule otway.induct, auto)
done


(** For reasoning about the encrypted portion of messages **)

lemma OR2_analz_knows_Spy:
     "[| Gets B \<lbrace>N, Agent A, Agent B, X\<rbrace> \<in> set evs;  evs \<in> otway |]
      ==> X \<in> analz (knows Spy evs)"
by blast

lemma OR4_analz_knows_Spy:
     "[| Gets B \<lbrace>N, X, Crypt (shrK B) X'\<rbrace> \<in> set evs;  evs \<in> otway |]
      ==> X \<in> analz (knows Spy evs)"
by blast

(*These lemmas assist simplification by removing forwarded X-variables.
  We can replace them by rewriting with parts_insert2 and proving using
  dest: parts_cut, but the proofs become more difficult.*)
lemmas OR2_parts_knows_Spy =
    OR2_analz_knows_Spy [THEN analz_into_parts]

(*There could be OR4_parts_knows_Spy and Oops_parts_knows_Spy, but for
  some reason proofs work without them!*)


text\<open>Theorems of the form @{term "X \<notin> parts (spies evs)"} imply that
NOBODY sends messages containing X!\<close>

text\<open>Spy never sees a good agent's shared key!\<close>
lemma Spy_see_shrK [simp]:
     "evs \<in> otway ==> (Key (shrK A) \<in> parts (knows Spy evs)) = (A \<in> bad)"
by (erule otway.induct, force,
    drule_tac [4] OR2_parts_knows_Spy, simp_all, blast+)


lemma Spy_analz_shrK [simp]:
     "evs \<in> otway ==> (Key (shrK A) \<in> analz (knows Spy evs)) = (A \<in> bad)"
by auto

lemma Spy_see_shrK_D [dest!]:
     "[|Key (shrK A) \<in> parts (knows Spy evs);  evs \<in> otway|] ==> A \<in> bad"
by (blast dest: Spy_see_shrK)


subsection\<open>Towards Secrecy: Proofs Involving @{term analz}\<close>

(*Describes the form of K and NA when the Server sends this message.  Also
  for Oops case.*)
lemma Says_Server_message_form:
     "[| Says Server B \<lbrace>NA, X, Crypt (shrK B) \<lbrace>NB, Key K\<rbrace>\<rbrace> \<in> set evs;
         evs \<in> otway |]
      ==> K \<notin> range shrK & (\<exists>i. NA = Nonce i) & (\<exists>j. NB = Nonce j)"
by (erule rev_mp, erule otway.induct, simp_all)


(****
 The following is to prove theorems of the form

  Key K \<in> analz (insert (Key KAB) (knows Spy evs)) ==>
  Key K \<in> analz (knows Spy evs)

 A more general formula must be proved inductively.
****)


text\<open>Session keys are not used to encrypt other session keys\<close>

text\<open>The equality makes the induction hypothesis easier to apply\<close>
lemma analz_image_freshK [rule_format]:
 "evs \<in> otway ==>
   \<forall>K KK. KK <= -(range shrK) -->
          (Key K \<in> analz (Key`KK Un (knows Spy evs))) =
          (K \<in> KK | Key K \<in> analz (knows Spy evs))"
apply (erule otway.induct)
apply (frule_tac [8] Says_Server_message_form)
apply (drule_tac [7] OR4_analz_knows_Spy)
apply (drule_tac [5] OR2_analz_knows_Spy, analz_freshK, spy_analz, auto) 
done

lemma analz_insert_freshK:
  "[| evs \<in> otway;  KAB \<notin> range shrK |] ==>
      (Key K \<in> analz (insert (Key KAB) (knows Spy evs))) =
      (K = KAB | Key K \<in> analz (knows Spy evs))"
by (simp only: analz_image_freshK analz_image_freshK_simps)


text\<open>The Key K uniquely identifies the Server's  message.\<close>
lemma unique_session_keys:
     "[| Says Server B \<lbrace>NA, X, Crypt (shrK B) \<lbrace>NB, K\<rbrace>\<rbrace>   \<in> set evs;
         Says Server B' \<lbrace>NA',X',Crypt (shrK B') \<lbrace>NB',K\<rbrace>\<rbrace> \<in> set evs;
         evs \<in> otway |] ==> X=X' & B=B' & NA=NA' & NB=NB'"
apply (erule rev_mp)
apply (erule rev_mp)
apply (erule otway.induct, simp_all)
apply blast+  \<comment>\<open>OR3 and OR4\<close>
done


subsection\<open>Authenticity properties relating to NA\<close>

text\<open>Only OR1 can have caused such a part of a message to appear.\<close>
lemma Crypt_imp_OR1 [rule_format]:
 "[| A \<notin> bad;  evs \<in> otway |]
  ==> Crypt (shrK A) \<lbrace>NA, Agent A, Agent B\<rbrace> \<in> parts (knows Spy evs) -->
      Says A B \<lbrace>NA, Agent A, Agent B,
                 Crypt (shrK A) \<lbrace>NA, Agent A, Agent B\<rbrace>\<rbrace>
        \<in> set evs"
by (erule otway.induct, force,
    drule_tac [4] OR2_parts_knows_Spy, simp_all, blast+)

lemma Crypt_imp_OR1_Gets:
     "[| Gets B \<lbrace>NA, Agent A, Agent B,
                  Crypt (shrK A) \<lbrace>NA, Agent A, Agent B\<rbrace>\<rbrace> \<in> set evs;
         A \<notin> bad; evs \<in> otway |]
       ==> Says A B \<lbrace>NA, Agent A, Agent B,
                      Crypt (shrK A) \<lbrace>NA, Agent A, Agent B\<rbrace>\<rbrace>
             \<in> set evs"
by (blast dest: Crypt_imp_OR1)


text\<open>The Nonce NA uniquely identifies A's message\<close>
lemma unique_NA:
     "[| Crypt (shrK A) \<lbrace>NA, Agent A, Agent B\<rbrace> \<in> parts (knows Spy evs);
         Crypt (shrK A) \<lbrace>NA, Agent A, Agent C\<rbrace> \<in> parts (knows Spy evs);
         evs \<in> otway;  A \<notin> bad |]
      ==> B = C"
apply (erule rev_mp, erule rev_mp)
apply (erule otway.induct, force,
       drule_tac [4] OR2_parts_knows_Spy, simp_all, blast+)
done


text\<open>It is impossible to re-use a nonce in both OR1 and OR2.  This holds because
  OR2 encrypts Nonce NB.  It prevents the attack that can occur in the
  over-simplified version of this protocol: see \<open>OtwayRees_Bad\<close>.\<close>
lemma no_nonce_OR1_OR2:
   "[| Crypt (shrK A) \<lbrace>NA, Agent A, Agent B\<rbrace> \<in> parts (knows Spy evs);
       A \<notin> bad;  evs \<in> otway |]
    ==> Crypt (shrK A) \<lbrace>NA', NA, Agent A', Agent A\<rbrace> \<notin> parts (knows Spy evs)"
apply (erule rev_mp)
apply (erule otway.induct, force,
       drule_tac [4] OR2_parts_knows_Spy, simp_all, blast+)
done

text\<open>Crucial property: If the encrypted message appears, and A has used NA
  to start a run, then it originated with the Server!\<close>
lemma NA_Crypt_imp_Server_msg [rule_format]:
     "[| A \<notin> bad;  evs \<in> otway |]
      ==> Says A B \<lbrace>NA, Agent A, Agent B,
                     Crypt (shrK A) \<lbrace>NA, Agent A, Agent B\<rbrace>\<rbrace> \<in> set evs -->
          Crypt (shrK A) \<lbrace>NA, Key K\<rbrace> \<in> parts (knows Spy evs)
          --> (\<exists>NB. Says Server B
                         \<lbrace>NA,
                           Crypt (shrK A) \<lbrace>NA, Key K\<rbrace>,
                           Crypt (shrK B) \<lbrace>NB, Key K\<rbrace>\<rbrace> \<in> set evs)"
apply (erule otway.induct, force,
       drule_tac [4] OR2_parts_knows_Spy, simp_all, blast)
apply blast  \<comment>\<open>OR1: by freshness\<close>
apply (blast dest!: no_nonce_OR1_OR2 intro: unique_NA)  \<comment>\<open>OR3\<close>
apply (blast intro!: Crypt_imp_OR1)  \<comment>\<open>OR4\<close>
done


text\<open>Corollary: if A receives B's OR4 message and the nonce NA agrees
  then the key really did come from the Server!  CANNOT prove this of the
  bad form of this protocol, even though we can prove
  \<open>Spy_not_see_encrypted_key\<close>\<close>
lemma A_trusts_OR4:
     "[| Says A  B \<lbrace>NA, Agent A, Agent B,
                     Crypt (shrK A) \<lbrace>NA, Agent A, Agent B\<rbrace>\<rbrace> \<in> set evs;
         Says B' A \<lbrace>NA, Crypt (shrK A) \<lbrace>NA, Key K\<rbrace>\<rbrace> \<in> set evs;
     A \<notin> bad;  evs \<in> otway |]
  ==> \<exists>NB. Says Server B
               \<lbrace>NA,
                 Crypt (shrK A) \<lbrace>NA, Key K\<rbrace>,
                 Crypt (shrK B) \<lbrace>NB, Key K\<rbrace>\<rbrace>
                 \<in> set evs"
by (blast intro!: NA_Crypt_imp_Server_msg)


text\<open>Crucial secrecy property: Spy does not see the keys sent in msg OR3
    Does not in itself guarantee security: an attack could violate
    the premises, e.g. by having @{term "A=Spy"}\<close>
lemma secrecy_lemma:
 "[| A \<notin> bad;  B \<notin> bad;  evs \<in> otway |]
  ==> Says Server B
        \<lbrace>NA, Crypt (shrK A) \<lbrace>NA, Key K\<rbrace>,
          Crypt (shrK B) \<lbrace>NB, Key K\<rbrace>\<rbrace> \<in> set evs -->
      Notes Spy \<lbrace>NA, NB, Key K\<rbrace> \<notin> set evs -->
      Key K \<notin> analz (knows Spy evs)"
apply (erule otway.induct, force)
apply (frule_tac [7] Says_Server_message_form)
apply (drule_tac [6] OR4_analz_knows_Spy)
apply (drule_tac [4] OR2_analz_knows_Spy)
apply (simp_all add: analz_insert_eq analz_insert_freshK pushes)
apply spy_analz  \<comment>\<open>Fake\<close>
apply (blast dest: unique_session_keys)+  \<comment>\<open>OR3, OR4, Oops\<close>
done

theorem Spy_not_see_encrypted_key:
     "[| Says Server B
          \<lbrace>NA, Crypt (shrK A) \<lbrace>NA, Key K\<rbrace>,
                Crypt (shrK B) \<lbrace>NB, Key K\<rbrace>\<rbrace> \<in> set evs;
         Notes Spy \<lbrace>NA, NB, Key K\<rbrace> \<notin> set evs;
         A \<notin> bad;  B \<notin> bad;  evs \<in> otway |]
      ==> Key K \<notin> analz (knows Spy evs)"
by (blast dest: Says_Server_message_form secrecy_lemma)

text\<open>This form is an immediate consequence of the previous result.  It is 
similar to the assertions established by other methods.  It is equivalent
to the previous result in that the Spy already has @{term analz} and
@{term synth} at his disposal.  However, the conclusion 
@{term "Key K \<notin> knows Spy evs"} appears not to be inductive: all the cases
other than Fake are trivial, while Fake requires 
@{term "Key K \<notin> analz (knows Spy evs)"}.\<close>
lemma Spy_not_know_encrypted_key:
     "[| Says Server B
          \<lbrace>NA, Crypt (shrK A) \<lbrace>NA, Key K\<rbrace>,
                Crypt (shrK B) \<lbrace>NB, Key K\<rbrace>\<rbrace> \<in> set evs;
         Notes Spy \<lbrace>NA, NB, Key K\<rbrace> \<notin> set evs;
         A \<notin> bad;  B \<notin> bad;  evs \<in> otway |]
      ==> Key K \<notin> knows Spy evs"
by (blast dest: Spy_not_see_encrypted_key)


text\<open>A's guarantee.  The Oops premise quantifies over NB because A cannot know
  what it is.\<close>
lemma A_gets_good_key:
     "[| Says A  B \<lbrace>NA, Agent A, Agent B,
                     Crypt (shrK A) \<lbrace>NA, Agent A, Agent B\<rbrace>\<rbrace> \<in> set evs;
         Says B' A \<lbrace>NA, Crypt (shrK A) \<lbrace>NA, Key K\<rbrace>\<rbrace> \<in> set evs;
         \<forall>NB. Notes Spy \<lbrace>NA, NB, Key K\<rbrace> \<notin> set evs;
         A \<notin> bad;  B \<notin> bad;  evs \<in> otway |]
      ==> Key K \<notin> analz (knows Spy evs)"
by (blast dest!: A_trusts_OR4 Spy_not_see_encrypted_key)


subsection\<open>Authenticity properties relating to NB\<close>

text\<open>Only OR2 can have caused such a part of a message to appear.  We do not
  know anything about X: it does NOT have to have the right form.\<close>
lemma Crypt_imp_OR2:
     "[| Crypt (shrK B) \<lbrace>NA, NB, Agent A, Agent B\<rbrace> \<in> parts (knows Spy evs);
         B \<notin> bad;  evs \<in> otway |]
      ==> \<exists>X. Says B Server
                 \<lbrace>NA, Agent A, Agent B, X,
                   Crypt (shrK B) \<lbrace>NA, NB, Agent A, Agent B\<rbrace>\<rbrace>
                 \<in> set evs"
apply (erule rev_mp)
apply (erule otway.induct, force,
       drule_tac [4] OR2_parts_knows_Spy, simp_all, blast+)
done


text\<open>The Nonce NB uniquely identifies B's  message\<close>
lemma unique_NB:
     "[| Crypt (shrK B) \<lbrace>NA, NB, Agent A, Agent B\<rbrace> \<in> parts(knows Spy evs);
         Crypt (shrK B) \<lbrace>NC, NB, Agent C, Agent B\<rbrace> \<in> parts(knows Spy evs);
           evs \<in> otway;  B \<notin> bad |]
         ==> NC = NA & C = A"
apply (erule rev_mp, erule rev_mp)
apply (erule otway.induct, force,
       drule_tac [4] OR2_parts_knows_Spy, simp_all)
apply blast+  \<comment>\<open>Fake, OR2\<close>
done

text\<open>If the encrypted message appears, and B has used Nonce NB,
  then it originated with the Server!  Quite messy proof.\<close>
lemma NB_Crypt_imp_Server_msg [rule_format]:
 "[| B \<notin> bad;  evs \<in> otway |]
  ==> Crypt (shrK B) \<lbrace>NB, Key K\<rbrace> \<in> parts (knows Spy evs)
      --> (\<forall>X'. Says B Server
                     \<lbrace>NA, Agent A, Agent B, X',
                       Crypt (shrK B) \<lbrace>NA, NB, Agent A, Agent B\<rbrace>\<rbrace>
           \<in> set evs
           --> Says Server B
                \<lbrace>NA, Crypt (shrK A) \<lbrace>NA, Key K\<rbrace>,
                      Crypt (shrK B) \<lbrace>NB, Key K\<rbrace>\<rbrace>
                    \<in> set evs)"
apply simp
apply (erule otway.induct, force,
       drule_tac [4] OR2_parts_knows_Spy, simp_all)
apply blast  \<comment>\<open>Fake\<close>
apply blast  \<comment>\<open>OR2\<close>
apply (blast dest: unique_NB dest!: no_nonce_OR1_OR2)  \<comment>\<open>OR3\<close>
apply (blast dest!: Crypt_imp_OR2)  \<comment>\<open>OR4\<close>
done


text\<open>Guarantee for B: if it gets a message with matching NB then the Server
  has sent the correct message.\<close>
theorem B_trusts_OR3:
     "[| Says B Server \<lbrace>NA, Agent A, Agent B, X',
                         Crypt (shrK B) \<lbrace>NA, NB, Agent A, Agent B\<rbrace>\<rbrace>
           \<in> set evs;
         Gets B \<lbrace>NA, X, Crypt (shrK B) \<lbrace>NB, Key K\<rbrace>\<rbrace> \<in> set evs;
         B \<notin> bad;  evs \<in> otway |]
      ==> Says Server B
               \<lbrace>NA,
                 Crypt (shrK A) \<lbrace>NA, Key K\<rbrace>,
                 Crypt (shrK B) \<lbrace>NB, Key K\<rbrace>\<rbrace>
                 \<in> set evs"
by (blast intro!: NB_Crypt_imp_Server_msg)


text\<open>The obvious combination of \<open>B_trusts_OR3\<close> with 
      \<open>Spy_not_see_encrypted_key\<close>\<close>
lemma B_gets_good_key:
     "[| Says B Server \<lbrace>NA, Agent A, Agent B, X',
                         Crypt (shrK B) \<lbrace>NA, NB, Agent A, Agent B\<rbrace>\<rbrace>
           \<in> set evs;
         Gets B \<lbrace>NA, X, Crypt (shrK B) \<lbrace>NB, Key K\<rbrace>\<rbrace> \<in> set evs;
         Notes Spy \<lbrace>NA, NB, Key K\<rbrace> \<notin> set evs;
         A \<notin> bad;  B \<notin> bad;  evs \<in> otway |]
      ==> Key K \<notin> analz (knows Spy evs)"
by (blast dest!: B_trusts_OR3 Spy_not_see_encrypted_key)


lemma OR3_imp_OR2:
     "[| Says Server B
              \<lbrace>NA, Crypt (shrK A) \<lbrace>NA, Key K\<rbrace>,
                Crypt (shrK B) \<lbrace>NB, Key K\<rbrace>\<rbrace> \<in> set evs;
         B \<notin> bad;  evs \<in> otway |]
  ==> \<exists>X. Says B Server \<lbrace>NA, Agent A, Agent B, X,
                            Crypt (shrK B) \<lbrace>NA, NB, Agent A, Agent B\<rbrace>\<rbrace>
              \<in> set evs"
apply (erule rev_mp)
apply (erule otway.induct, simp_all)
apply (blast dest!: Crypt_imp_OR2)+
done


text\<open>After getting and checking OR4, agent A can trust that B has been active.
  We could probably prove that X has the expected form, but that is not
  strictly necessary for authentication.\<close>
theorem A_auths_B:
     "[| Says B' A \<lbrace>NA, Crypt (shrK A) \<lbrace>NA, Key K\<rbrace>\<rbrace> \<in> set evs;
         Says A  B \<lbrace>NA, Agent A, Agent B,
                     Crypt (shrK A) \<lbrace>NA, Agent A, Agent B\<rbrace>\<rbrace> \<in> set evs;
         A \<notin> bad;  B \<notin> bad;  evs \<in> otway |]
  ==> \<exists>NB X. Says B Server \<lbrace>NA, Agent A, Agent B, X,
                               Crypt (shrK B)  \<lbrace>NA, NB, Agent A, Agent B\<rbrace>\<rbrace>
                 \<in> set evs"
by (blast dest!: A_trusts_OR4 OR3_imp_OR2)

end
