(** Formal Reasoning About Programs <http://adam.chlipala.net/frap/>
  * Supplementary Coq material: first-class functions and continuations
  * Author: Adam Chlipala
  * License: https://creativecommons.org/licenses/by-nc-nd/4.0/ *)

Require Import Frap.


(** * Some data fodder for us to compute with later *)

Record programming_language := {
  Name : string;
  PurelyFunctional : bool;
  AppearedInYear : nat
}.

Definition pascal := {|
  Name := "Pascal";
  PurelyFunctional := false;
  AppearedInYear := 1970
|}.

Definition c := {|
  Name := "C";
  PurelyFunctional := false;
  AppearedInYear := 1972
|}.

Definition gallina := {|
  Name := "Gallina";
  PurelyFunctional := true;
  AppearedInYear := 1989
|}.

Definition haskell := {|
  Name := "Haskell";
  PurelyFunctional := true;
  AppearedInYear := 1990
|}.

Definition ocaml := {|
  Name := "OCaml";
  PurelyFunctional := false;
  AppearedInYear := 1996
|}.

Definition languages := [pascal; c; gallina; haskell; ocaml].


(** * Classic list functions *)

Fixpoint map {A B} (f : A -> B) (ls : list A) : list B :=
  match ls with
  | nil => nil
  | x :: ls' => f x :: map f ls'
  end.

Fixpoint filter {A} (f : A -> bool) (ls : list A) : list A :=
  match ls with
  | nil => nil
  | x :: ls' => if f x then x :: filter f ls' else filter f ls'
  end.

Fixpoint fold_left {A B} (f : B -> A -> B) (ls : list A) (acc : B) : B :=
  match ls with
  | nil => acc
  | x :: ls' => fold_left f ls' (f acc x)
  end.

Compute map Name languages.
Compute map Name (filter PurelyFunctional languages).
Compute fold_left max (map AppearedInYear languages) 0.
Compute fold_left max (map AppearedInYear (filter PurelyFunctional languages)) 0.

(* To avoid confusing things, we'll revert to the standard library's (identical)
 * versions of these functions for the remainder. *)
Reset map.


(** * Motivating continuations with search problems *)

Fixpoint allSublists {A} (ls : list A) : list (list A) :=
  match ls with
  | [] => [[]]
  | x :: ls' =>
    let lss := allSublists ls' in
    lss ++ map (fun ls'' => x :: ls'') lss
  end.

Definition sum ls := fold_left plus ls 0.

Fixpoint sublistSummingTo (ns : list nat) (target : nat) : option (list nat) :=
  match filter (fun ns' => if sum ns' ==n target then true else false) (allSublists ns) with
  | ns' :: _ => Some ns'
  | [] => None
  end.

Fixpoint countingDown (from : nat) :=
  match from with
  | O => []
  | S from' => from' :: countingDown from'
  end.

Time Compute sublistSummingTo (countingDown 20) 1.

Fixpoint allSublistsK {A B} (ls : list A)
         (failed : unit -> B)
         (found : list A -> (unit -> B) -> B) : B :=
  match ls with
  | [] => found [] failed
  | x :: ls' =>
    allSublistsK ls'
                 failed
                 (fun sol failed' =>
                    found sol (fun _ => found (x :: sol) failed'))
  end.

Definition sublistSummingToK (ns : list nat) (target : nat) : option (list nat) :=
  allSublistsK ns
               (fun _ => None)
               (fun sol failed =>
                  if sum sol ==n target then Some sol else failed tt).

Time Compute sublistSummingToK (countingDown 20) 1.

Theorem allSublistsK_ok : forall {A B} (ls : list A) (failed : unit -> B) found,
    (forall sol, (exists ans, (forall failed', found sol failed' = ans)
                              /\ ans <> failed tt)
                 \/ (forall failed', found sol failed' = failed' tt))
    -> (exists sol ans, In sol (allSublists ls)
                        /\ (forall failed', found sol failed' = ans)
                        /\ allSublistsK ls failed found = ans
                        /\ ans <> failed tt)
       \/ ((forall sol, In sol (allSublists ls)
                        -> forall failed', found sol failed' = failed' tt)
           /\ allSublistsK ls failed found = failed tt).
Proof.
  induct ls; simplify.

  specialize (H []).
  first_order.
  right.
  propositional.
  subst.
  trivial.
  trivial.

  assert (let found := (fun (sol : list A) (failed' : unit -> B) =>
     found sol (fun _ : unit => found (a :: sol) failed')) in
          (exists (sol : list A) (ans : B),
              In sol (allSublists ls) /\
              (forall failed' : unit -> B, found sol failed' = ans) /\
              allSublistsK ls failed found = ans /\ ans <> failed tt) \/
          (forall sol : list A,
              In sol (allSublists ls) -> forall failed' : unit -> B, found sol failed' = failed' tt) /\
          allSublistsK ls failed found = failed tt).
  apply IHls.
  first_order.
  generalize (H sol).
  first_order.
  specialize (H (a :: sol)).
  first_order.
  left.
  exists x; propositional.
  rewrite H0.
  trivial.
  right.
  simplify.
  rewrite H0.
  trivial.

  clear IHls.
  simplify.
  first_order.

  generalize (H x); first_order.
  left; exists x, x1; propositional.
  apply in_or_app; propositional.
  specialize (H1 failed).
  specialize (H4 (fun _ => found (a :: x) failed)).
  equality.
  left; exists (a :: x), x0; propositional.
  apply in_or_app; right; apply in_map_iff.
  first_order.
  specialize (H1 failed').
  rewrite H4 in H1.
  trivial.

  right; propositional.
  apply in_app_or in H2; propositional.

  generalize (H sol); first_order.
  apply H0 with (failed' := failed') in H3.
  rewrite H2 in H3.
  equality.

  apply in_map_iff in H3.
  first_order.
  subst.
  generalize (H x); first_order.
  apply H0 with (failed' := failed) in H3.
  equality.
  apply H0 with (failed' := failed') in H3.
  rewrite H2 in H3; trivial.
Qed.

Theorem sublistSummingToK_ok : forall ns target,
    match sublistSummingToK ns target with
    | None => forall sol, In sol (allSublists ns) -> sum sol <> target
    | Some sol => In sol (allSublists ns) /\ sum sol = target
    end.
Proof.
  simplify.
  unfold sublistSummingToK.
  pose proof (allSublistsK_ok ns (fun _ => None)
              (fun sol failed => if sum sol ==n target then Some sol else failed tt)).
  cases H.

  simplify.
  cases (sum sol ==n target).
  left; exists (Some sol); equality.
  propositional.

  first_order.
  specialize (H0 (fun _ => None)).
  cases (sum x ==n target); try equality.
  subst.
  rewrite H1.
  propositional.

  first_order.
  rewrite H0.
  simplify.
  apply H with (failed' := fun _ => None) in H1.
  cases (sum sol ==n target); equality.
Qed.


(** * The classics in continuation-passing style *)

Fixpoint mapK {A B R} (f : A -> (B -> R) -> R) (ls : list A) (k : list B -> R) : R :=
  match ls with
  | nil => k nil
  | x :: ls' => f x (fun x' => mapK f ls' (fun ls'' => k (x' :: ls'')))
  end.

Fixpoint filterK {A R} (f : A -> (bool -> R) -> R) (ls : list A) (k : list A -> R) : R :=
  match ls with
  | nil => k nil
  | x :: ls' => f x (fun b => filterK f ls' (fun ls'' => k (if b then x :: ls'' else ls'')))
  end.

Fixpoint fold_leftK {A B R} (f : B -> A -> (B -> R) -> R) (ls : list A) (acc : B) (k : B -> R) : R :=
  match ls with
  | nil => k acc
  | x :: ls' => f acc x (fun x' => fold_leftK f ls' x' k)
  end.

Definition NameK {R} (l : programming_language) (k : string -> R) : R :=
  k (Name l).
Definition PurelyFunctionalK {R} (l : programming_language) (k : bool -> R) : R :=
  k (PurelyFunctional l).
Definition AppearedInYearK {R} (l : programming_language) (k : nat -> R) : R :=
  k (AppearedInYear l).
Definition maxK {R} (n1 n2 : nat) (k : nat -> R) : R :=
  k (max n1 n2).

Compute mapK NameK languages (fun ls => ls).
Compute filterK PurelyFunctionalK languages (fun ls => mapK NameK ls (fun x => x)).
Compute mapK AppearedInYearK languages (fun ls => fold_leftK maxK ls 0 (fun x => x)).
Compute filterK PurelyFunctionalK languages
        (fun ls1 => mapK AppearedInYearK ls1
                         (fun ls2 => fold_leftK maxK ls2 0 (fun x => x))).

Theorem mapK_ok : forall {A B R} (f : A -> (B -> R) -> R) (f_base : A -> B),
    (forall x k, f x k = k (f_base x))
    -> forall (ls : list A) (k : list B -> R),
      mapK f ls k = k (map f_base ls).
Proof.
  induct ls; simplify; try equality.

  rewrite H.
  apply IHls.
Qed.

Theorem names_ok : forall langs,
    mapK NameK langs (fun ls => ls) = map Name langs.
Proof.
  simplify.
  apply mapK_ok with (f_base := Name).
  unfold NameK.
  trivial.
Qed.

Theorem filterK_ok : forall {A R} (f : A -> (bool -> R) -> R) (f_base : A -> bool),
    (forall x k, f x k = k (f_base x))
    -> forall (ls : list A) (k : list A -> R),
      filterK f ls k = k (filter f_base ls).
Proof.
  induct ls; simplify; try equality.

  rewrite H.
  apply IHls.
Qed.

Theorem purenames_ok : forall langs,
    filterK PurelyFunctionalK langs (fun ls => mapK NameK ls (fun x => x))
    = map Name (filter PurelyFunctional langs).
Proof.
  simplify.
  rewrite filterK_ok with (f_base := PurelyFunctional); trivial.
  apply mapK_ok with (f_base := Name); trivial.
Qed.

Theorem fold_leftK_ok : forall {A B R} (f : B -> A -> (B -> R) -> R) (f_base : B -> A -> B),
    (forall x acc k, f x acc k = k (f_base x acc))
    -> forall (ls : list A) (acc : B) (k : B -> R),
      fold_leftK f ls acc k = k (fold_left f_base ls acc).
Proof.
  induct ls; simplify; try equality.

  rewrite H.
  apply IHls.
Qed.

Theorem latest_ok : forall langs,
    mapK AppearedInYearK langs (fun ls => fold_leftK maxK ls 0 (fun x => x))
    = fold_left max (map AppearedInYear langs) 0.
Proof.
  simplify.
  rewrite mapK_ok with (f_base := AppearedInYear); trivial.
  apply fold_leftK_ok with (f_base := max); trivial.
Qed.

Theorem latestpure_ok : forall langs,
    filterK PurelyFunctionalK langs
            (fun ls1 => mapK AppearedInYearK ls1
                             (fun ls2 => fold_leftK maxK ls2 0 (fun x => x)))
    = fold_left max (map AppearedInYear (filter PurelyFunctional langs)) 0.
Proof.
  simplify.
  rewrite filterK_ok with (f_base := PurelyFunctional); trivial.
  rewrite mapK_ok with (f_base := AppearedInYear); trivial.
  apply fold_leftK_ok with (f_base := max); trivial.
Qed.


(** * Tree traversals *)

Inductive tree {A} :=
| Leaf
| Node (l : tree) (d : A) (r : tree).
Arguments tree : clear implicits.

Fixpoint size {A} (t : tree A) : nat :=
  match t with
  | Leaf => 0
  | Node l _ r => 2 + size l + size r
  end.

Fixpoint flatten {A} (t : tree A) : list A :=
  match t with
  | Leaf => []
  | Node l d r => flatten l ++ d :: flatten r
  end.

Fixpoint flattenAcc {A} (t : tree A) (acc : list A) : list A :=
  match t with
  | Leaf => acc
  | Node l d r => flattenAcc l (d :: flattenAcc r acc)
  end.

Theorem flattenAcc_ok : forall {A} (t : tree A) acc,
    flattenAcc t acc = flatten t ++ acc.
Proof.
  induct t; simplify; try equality.

  rewrite IHt1, IHt2.
  rewrite <- app_assoc.
  simplify.
  equality.
Qed.

Fixpoint flattenK {A R} (t : tree A) (acc : list A) (k : list A -> R) : R :=
  match t with
  | Leaf => k acc
  | Node l d r => flattenK r acc (fun acc' =>
                                    flattenK l (d :: acc') k)
  end.

Theorem flattenK_ok : forall {A R} (t : tree A) acc (k : list A -> R),
    flattenK t acc k = k (flattenAcc t acc).
Proof.
  induct t; simplify; try equality.

  rewrite IHt2, IHt1.
  equality.
Qed.

Inductive flatten_continuation {A} :=
| KDone
| KMore (l : tree A) (d : A) (k : flatten_continuation).
Arguments flatten_continuation : clear implicits.

Definition apply_continuation {A} (acc : list A) (k : flatten_continuation A)
         (flattenKD : tree A -> list A -> flatten_continuation A -> list A)
         : list A :=
  match k with
  | KDone => acc
  | KMore l d k' => flattenKD l (d :: acc) k'
  end.

Fixpoint flattenKD {A} (fuel : nat) (t : tree A) (acc : list A)
         (k : flatten_continuation A) : list A :=
  match fuel with
  | O => []
  | S fuel' =>
    match t with
    | Leaf => apply_continuation acc k (flattenKD fuel')
    | Node l d r => flattenKD fuel' r acc (KMore l d k)
    end
  end.

Fixpoint continuation_size {A} (k : flatten_continuation A) : nat :=
  match k with
  | KDone => 0
  | KMore l d k' => 1 + size l + continuation_size k'
  end.

Fixpoint flatten_cont {A} (k : flatten_continuation A) : list A :=
  match k with
  | KDone => []
  | KMore l d k' => flatten_cont k' ++ flatten l ++ [d]
  end.

Lemma flattenKD_ok' : forall {A} fuel fuel' (t : tree A) acc k,
    size t + continuation_size k < fuel' < fuel
    -> flattenKD fuel' t acc k
       = flatten_cont k ++ flatten t ++ acc.
Proof.
  induct fuel; simplify; cases fuel'; simplify; try linear_arithmetic.

  cases t; simplify; trivial.

  cases k; simplify; trivial.
  rewrite IHfuel; try linear_arithmetic.
  repeat rewrite <- app_assoc.
  simplify.
  equality.

  rewrite IHfuel.
  simplify.
  repeat rewrite <- app_assoc.
  simplify.
  equality.
  simplify.
  linear_arithmetic.
Qed.

Theorem flattenKD_ok : forall {A} (t : tree A),
    flattenKD (size t + 1) t [] KDone = flatten t.
Proof.
  simplify.
  rewrite flattenKD_ok' with (fuel := size t + 2).
  simplify.
  apply app_nil_r.
  simplify.
  linear_arithmetic.
Qed.

Definition call_stack A := list (tree A * A).

Definition pop_call_stack {A} (acc : list A) (st : call_stack A)
         (flattenS : tree A -> list A -> call_stack A -> list A)
         : list A :=
  match st with
  | [] => acc
  | (l, d) :: st' => flattenS l (d :: acc) st'
  end.

Fixpoint flattenS {A} (fuel : nat) (t : tree A) (acc : list A)
         (st : call_stack A) : list A :=
  match fuel with
  | O => []
  | S fuel' =>
    match t with
    | Leaf => pop_call_stack acc st (flattenS fuel')
    | Node l d r => flattenS fuel' r acc ((l, d) :: st)
    end
  end.

Fixpoint call_stack_to_continuation {A} (st : call_stack A) : flatten_continuation A :=
  match st with
  | [] => KDone
  | (l, d) :: st' => KMore l d (call_stack_to_continuation st')
  end.

Lemma flattenS_flattenKD : forall {A} fuel (t : tree A) acc st,
    flattenS fuel t acc st = flattenKD fuel t acc (call_stack_to_continuation st).
Proof.
  induct fuel; simplify; trivial.

  cases t.

  cases st; simplify; trivial.
  cases p; simplify.
  apply IHfuel.

  apply IHfuel.
Qed.

Theorem flattenS_ok : forall {A} (t : tree A),
    flattenS (size t + 1) t [] [] = flatten t.
Proof.
  simplify.
  rewrite flattenS_flattenKD.
  apply flattenKD_ok.
Qed.
