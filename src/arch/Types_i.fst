module Types_i

open Opaque_s
open Types_s
open TypesNative_i
open Collections.Seqs_i
open Words_s
open Words.Two_i

let lemma_BitwiseXorCommutative x y =
  lemma_ixor_nth_all 32;
  lemma_equal_nth 32 (x *^ y) (y *^ x)

let lemma_BitwiseXorWithZero n =
  lemma_ixor_nth_all 32;
  lemma_zero_nth 32;
  lemma_equal_nth 32 (n *^ 0) n

let lemma_BitwiseXorCancel n =
  lemma_ixor_nth_all 32;
  lemma_zero_nth 32;
  lemma_equal_nth 32 (n *^ n) 0

let lemma_BitwiseXorCancel64 (n:nat64) =
  lemma_ixor_nth_all 64;
  lemma_zero_nth 64;
  lemma_equal_nth 64 (ixor n n) 0 

let lemma_BitwiseXorAssociative x y z =
  lemma_ixor_nth_all 32;
  lemma_equal_nth 32 (x *^ (y *^ z)) ((x *^ y) *^ z)

let xor_lemmas () =
  FStar.Classical.forall_intro_2 lemma_BitwiseXorCommutative;
  FStar.Classical.forall_intro lemma_BitwiseXorWithZero;
  FStar.Classical.forall_intro lemma_BitwiseXorCancel;
  FStar.Classical.forall_intro lemma_BitwiseXorCancel64;
  FStar.Classical.forall_intro_3 lemma_BitwiseXorAssociative;
  ()

let lemma_quad32_xor () =
  xor_lemmas()

let lemma_reverse_reverse_bytes_nat32 (n:nat32) :
  Lemma (reverse_bytes_nat32 (reverse_bytes_nat32 n) == n)
  =
  let r = reverse_seq (nat32_to_be_bytes n) in
  be_bytes_to_nat32_to_be_bytes r;
  ()

let lemma_reverse_bytes_quad32 (q:quad32) =
  reveal_reverse_bytes_quad32 q;
  reveal_reverse_bytes_quad32 (reverse_bytes_quad32 q);
  ()

let lemma_reverse_reverse_bytes_nat32_seq (s:seq nat32) :
  Lemma (ensures reverse_bytes_nat32_seq (reverse_bytes_nat32_seq s) == s)
  =
  reveal_reverse_bytes_nat32_seq s;
  reveal_reverse_bytes_nat32_seq (reverse_bytes_nat32_seq s);
  assert (equal (reverse_bytes_nat32_seq (reverse_bytes_nat32_seq s)) s)

(*
let lemma_equality_check_helper_two_to_nat_32 (n:two nat32) :
  Lemma ( ((n.lo == 0 /\ n.hi == 0) ==> two_to_nat 32 n == 0) /\
          ( ~(n.lo == 0) \/ (~(n.hi == 0))) ==> ~(two_to_nat 32 n == 0) /\
          ((n.lo == 0xFFFFFFFF /\ n.hi == 0xFFFFFFFF) <==> two_to_nat 32 n == 0xFFFFFFFFFFFFFFFF))
  =
  let open FStar.Mul in
  if n.lo == 0 /\ n.hi == 0 then (
    assert (int_to_natN pow2_64 (n.lo + pow2_32 * n.hi) == 0);
    ()
  ) else (
    ()
  );
  ()

let lemma_equality_check_helper_lo (q:quad32) : 
  Lemma ((q.lo0 == 0 /\ q.lo1 == 0 ==> lo64 q == 0) /\ 
         ((not (q.lo0 = 0) \/ not (q.lo1 = 0)) ==> not (lo64 q = 0)) /\
         (q.lo0 == 0xFFFFFFFF /\ q.lo1 == 0xFFFFFFFF <==> lo64 q == 0xFFFFFFFFFFFFFFFF))
  =
  assert (lo64 q == two_to_nat 32 (Mktwo q.lo0 q.lo1));
  lemma_equality_check_helper_two_to_nat_32 (Mktwo q.lo0 q.lo1);  
  ()

let lemma_equality_check_helper_hi (q:quad32) : 
  Lemma ((q.hi2 == 0 /\ q.hi3 == 0 ==> hi64 q == 0) /\ 
         ((~(q.hi2 = 0) \/ ~(q.hi3 = 0)) ==> ~(hi64 q = 0)) /\
         (q.hi2 == 0xFFFFFFFF /\ q.hi3 == 0xFFFFFFFF <==> hi64 q == 0xFFFFFFFFFFFFFFFF))
  =
  assert (hi64 q == two_to_nat 32 (Mktwo q.hi2 q.hi3));
  lemma_equality_check_helper_two_to_nat_32 (Mktwo q.hi2 q.hi3);
  ()
*)

let lemma_equality_check_helper (q:quad32) :
  Lemma ((q.lo0 == 0 /\ q.lo1 == 0 ==> lo64 q == 0) /\ 
         ((not (q.lo0 = 0) \/ not (q.lo1 = 0)) ==> not (lo64 q = 0)) /\
         (q.hi2 == 0 /\ q.hi3 == 0 ==> hi64 q == 0) /\ 
         ((~(q.hi2 = 0) \/ ~(q.hi3 = 0)) ==> ~(hi64 q = 0)) /\
         (q.lo0 == 0xFFFFFFFF /\ q.lo1 == 0xFFFFFFFF <==> lo64 q == 0xFFFFFFFFFFFFFFFF) /\
         (q.hi2 == 0xFFFFFFFF /\ q.hi3 == 0xFFFFFFFF <==> hi64 q == 0xFFFFFFFFFFFFFFFF)
         )
  =
//  lemma_equality_check_helper_lo q;
//  lemma_equality_check_helper_hi q;
  assert (forall (x:two nat32).{:pattern (two_to_nat 32 x)} two_to_nat 32 x == two_to_nat_unfold 32 x);
  ()


let push_pop_xmm (x y:quad32) : Lemma 
  (let x' = insert_nat64 (insert_nat64 y (hi64 x) 1) (lo64 x) 0 in
   x == x')
   =
//   assert (nat_to_two 32 (hi64 x) == two_select (four_to_two_two x) 1);
   ()

#reset-options "--z3rlimit 10 --max_fuel 0 --max_ifuel 0 --using_facts_from '* -FStar.Seq.Properties'"
let le_bytes_to_seq_quad32_to_bytes_one_quad (b:quad32) :
  Lemma (le_bytes_to_seq_quad32 (le_quad32_to_bytes b) == create 1 b)
(* This expands into showing:
   le_bytes_to_seq_quad32 (le_quad32_to_bytes b)
 == { definition of le_bytes_to_seq_quad32 }
   seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (le_quad32_to_bytes b))
 == { definition of le_quad32_to_bytes }
   seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b))))
 == { definition of seq_nat8_to_seq_nat32_LE }
   seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b)))))
 == { seq_to_seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b)) }
   seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_map (nat_to_four 8) (four_to_seq_LE b)))
 == { seq_map_inverses (four_to_nat 8) (nat_to_four 8) (four_to_seq_LE b) }
   seq_to_seq_four_LE (four_to_seq_LE b)
 == { four_to_seq_LE_is_seq_four_to_seq_LE b }
   seq_to_seq_four_LE (seq_four_to_seq_LE (create 1 b))
 == { seq_to_seq_four_to_seq_LE (create 1 b) }
   create 1 b
 *)
  =
  reveal_opaque le_bytes_to_seq_quad32_def;
  reveal_opaque le_quad32_to_bytes_def;
  seq_to_seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b));
  seq_map_inverses (nat_to_four 8) (four_to_nat 8) (four_to_seq_LE b);
  four_to_seq_LE_is_seq_four_to_seq_LE b;
  seq_to_seq_four_to_seq_LE (create 1 b) ;
  (*
  assert (le_bytes_to_seq_quad32 (le_quad32_to_bytes b) == seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (le_quad32_to_bytes b)));
  assert (le_quad32_to_bytes b == seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b)));
  assert ((le_bytes_to_seq_quad32 (le_quad32_to_bytes b)) == 
          (seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b)))))
          ); 
  let annoying_definition_expander (x:seq nat8{length x % 4 == 0}) :
    Lemma ( (seq_nat8_to_seq_nat32_LE (x)) ==
           (seq_map (four_to_nat 8) (seq_to_seq_four_LE x) )) = () in

  let (s:seq nat8{length s % 4 == 0}) = seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b)) in
  //annoying_definition_expander s;
  assert ( (seq_nat8_to_seq_nat32_LE (s)) ==
           (seq_map (four_to_nat 8) (seq_to_seq_four_LE s) ));
           
  assert ( (le_bytes_to_seq_quad32 (le_quad32_to_bytes b)) ==
           seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE s)) );           
  assert (seq_to_seq_four_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b))) ==
          seq_map (nat_to_four 8) (four_to_seq_LE b));
  assert ( (le_bytes_to_seq_quad32 (le_quad32_to_bytes b)) ==
           seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_map (nat_to_four 8) (four_to_seq_LE b))) );
  (*
  assert ( (seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b))))))
                   ==
                  (seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_map (nat_to_four 8) (four_to_seq_LE b)))));
                  *)
  //assert (equal (le_bytes_to_seq_quad32 (le_quad32_to_bytes b)) (create 1 b));
  *)
  ()
 

(*
  Let s4 = seq_map (nat_to_four 8) (four_to_seq_LE b) in
  let s4wrapped = seq_to_seq_four_LE (seq_four_to_seq_LE s4) in
  assert (s4wrapped == s4);
  seq_map_inverses (nat_to_four 8) (four_to_nat 8) (four_to_seq_LE b);
  seq_to_seq_four_to_seq_LE (create 1 b);
  four_to_seq_LE_is_seq_four_to_seq_LE b;

  assert (le_bytes_to_seq_quad32 (le_quad32_to_bytes b) ==
            seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (le_quad32_to_bytes b)));
  assert (equal (le_quad32_to_bytes b) (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b))));
  (*
  assert (equal (seq_nat8_to_seq_nat32_LE (le_quad32_to_bytes b)) 
                (seq_nat8_to_seq_nat32_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b)))));
  *)
  assert (equal (seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (le_quad32_to_bytes b)))
          (seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE b))))));
  ()
*)


let le_bytes_to_seq_quad32_to_bytes (s:seq quad32) :
  Lemma (le_bytes_to_seq_quad32 (le_seq_quad32_to_bytes s) == s)
(* This expands into showing:
   le_bytes_to_seq_quad32 (le_quad32_to_bytes s)
 == { definition of le_bytes_to_seq_quad32 }
   seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (le_seq_quad32_to_bytes s))
 == { definition of le_seq_quad32_to_bytes }
   seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE (seq_nat32_to_seq_nat8_LE (seq_four_to_seq_LE s)))
 == { definition of seq_nat8_to_seq_nat32_LE }
   seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE (seq_nat32_to_seq_nat8_LE (seq_four_to_seq_LE s))))
 == { definition of seq_nat32_to_seq_nat8_LE }
    seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE (seq_four_to_seq_LE (seq_map (nat_to_four 8) (seq_four_to_seq_LE s)))))
 *)
  =
  reveal_opaque le_bytes_to_seq_quad32_def;
  reveal_opaque le_seq_quad32_to_bytes_def;
  seq_to_seq_four_to_seq_LE (seq_map (nat_to_four 8) (seq_four_to_seq_LE s));
  seq_map_inverses (nat_to_four 8) (four_to_nat 8) (seq_four_to_seq_LE s);
  seq_to_seq_four_to_seq_LE (s) ;
  ()

(*
le_quad32_to_bytes (le_bytes_to_quad32 s) 
== { definition of le_quad32_to_bytes }
seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE (le_bytes_to_quad32 s)))
== { definition of le_bytes_to_quad32 }
seq_four_to_seq_LE (seq_map (nat_to_four 8) (four_to_seq_LE (seq_to_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE s)))))
*)

let le_quad32_to_bytes_to_quad32 (s:seq nat8 { length s == 16 }) :
  Lemma(le_quad32_to_bytes (le_bytes_to_quad32 s) == s)
  =
  reveal_opaque le_bytes_to_quad32_def;
  reveal_opaque le_quad32_to_bytes_def;
  let q = le_bytes_to_quad32 s in
  let s' = le_quad32_to_bytes q in
  if not (s = s') then (
    four_to_seq_to_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE s));
    let helper (x:four (natN (pow2_norm 8))) : Lemma (nat_to_four 8 (four_to_nat 8 x) == x) =
      nat_to_four_to_nat x
    in
    FStar.Classical.forall_intro helper;  // Prove the inverse property needed for seq_map_inverses
    seq_map_inverses (four_to_nat 8) (nat_to_four 8) (seq_to_seq_four_LE s);
    seq_four_to_seq_to_seq_four_LE s;
    ()
  ) else (
    assert (s == s')
  )

let le_seq_quad32_to_bytes_of_singleton (q:quad32) :
  Lemma (le_quad32_to_bytes q == le_seq_quad32_to_bytes (create 1 q))
  =
  reveal_opaque le_seq_quad32_to_bytes_def;
  reveal_opaque le_quad32_to_bytes_def;
  four_to_seq_LE_is_seq_four_to_seq_LE q;
  ()

let le_quad32_to_bytes_injective ():
  Lemma (forall b b' . le_quad32_to_bytes b == le_quad32_to_bytes b' ==> b == b')
  =
  reveal_opaque le_quad32_to_bytes_def;
  let helper (b b':quad32) : Lemma (le_quad32_to_bytes b == le_quad32_to_bytes b' ==> b == b') =
    if le_quad32_to_bytes b = le_quad32_to_bytes b' then (
      let b1  = seq_map (nat_to_four 8) (four_to_seq_LE b) in
      let b1' = seq_map (nat_to_four 8) (four_to_seq_LE b') in
      assert (le_quad32_to_bytes b == seq_four_to_seq_LE b1);
      assert (le_quad32_to_bytes b' == seq_four_to_seq_LE b1');
      seq_four_to_seq_LE_injective_specific b1 b1';
      assert (b1 == b1');
      nat_to_four_8_injective();
      seq_map_injective (nat_to_four 8) (four_to_seq_LE b) (four_to_seq_LE b');
      assert ((four_to_seq_LE b) == (four_to_seq_LE b'));
      four_to_seq_LE_injective nat32;
      ()
    ) else
    ()
  in 
  FStar.Classical.forall_intro_2 helper

let le_quad32_to_bytes_injective_specific (b b':quad32) : 
  Lemma (le_quad32_to_bytes b == le_quad32_to_bytes b' ==> b == b')
  =
  le_quad32_to_bytes_injective()

(*

let seq_to_four_LE (#a:Type) (s:seq4 a) : four a =
  Mkfour (index s 0) (index s 1) (index s 2) (index s 3)
  
let seq_to_seq_four_LE (#a:Type) (x:seq a{length x % 4 == 0}) : seq (four a) =
  let f (n:nat{n < length x / 4}) = Mkfour
    (index x (n * 4)) (index x (n * 4 + 1)) (index x (n * 4 + 2)) (index x (n * 4 + 3))
    in
  init (length x / 4) f

let seq_nat8_to_seq_nat32_LE (x:seq nat8{length x % 4 == 0}) : seq nat32 =
  seq_map (four_to_nat 8) (seq_to_seq_four_LE x)

*)  
let seq_to_four_LE_is_seq_to_seq_four_LE (#a:Type) (s:seq4 a) : Lemma
  (create 1 (seq_to_four_LE s) == seq_to_seq_four_LE s)
  =
  assert (equal (create 1 (seq_to_four_LE s)) (seq_to_seq_four_LE s));
  ()

let le_bytes_to_seq_quad_of_singleton (q:quad32) (b:seq nat8 { length b == 16 }) : Lemma 
  (requires q == le_bytes_to_quad32 b)
  (ensures create 1 q == le_bytes_to_seq_quad32 b)
  =
  reveal_opaque le_bytes_to_seq_quad32_def;
  reveal_opaque le_bytes_to_quad32_def;
  seq_to_four_LE_is_seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE b));
  // q == le_bytes_to_quad32 b
  //   == seq_to_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE b))
  //  

  //     == seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE b))
  // le_bytes_to_seq_quad32 b == seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE b)
  ()

// let be_quad32_to_bytes (q:quad32) : seqn 16 nat8 =
//   seq_four_to_seq_BE (seq_map (nat_to_four 8) (four_to_seq_BE q))

// be_bytes_to_quad32 (be_quad32_to_bytes q)
//   { definition of be_bytes_to_quad32 }
// seq_to_four_BE (seq_map (four_to_nat 8) (seq_to_seq_four_BE (be_quad32_to_bytes q)))
//   { definition of be_quad32_to_bytes }
// seq_to_four_BE (seq_map (four_to_nat 8) (seq_to_seq_four_BE (seq_four_to_seq_BE (seq_map (nat_to_four 8) (four_to_seq_BE q)))))
//    { seq_to_seq_four_to_seq_BE (seq_map (nat_to_four 8) (seq_four_to_seq_BE q)); }
// seq_to_four_BE (seq_map (four_to_nat 8) (seq_map (nat_to_four 8) (four_to_seq_BE q)))
//    { seq_map_inverses  (four_to_nat 8) (nat_to_four 8) (four_to_seq_BE q); }
// seq_to_four_BE (four_to_seq_BE q)
//    { seq_to_four_to_seq_BE q }
//  q

let be_bytes_to_quad32_to_bytes (q:quad32) : 
  Lemma (be_bytes_to_quad32 (be_quad32_to_bytes q) == q)
  =
  reveal_opaque be_bytes_to_quad32_def;
  let q':quad32 = be_bytes_to_quad32 (be_quad32_to_bytes q) in
  seq_to_seq_four_to_seq_BE (seq_map (nat_to_four 8) (four_to_seq_BE q));
  seq_map_inverses (nat_to_four 8) (four_to_nat 8) (four_to_seq_BE q);
  seq_to_four_to_seq_BE q;
  ()

open FStar.Mul
let slice_commutes_seq_four_to_seq_LE (#a:Type) (s:seq (four a)) (n:nat{n <= length s}) (n':nat{ n <= n' /\ n' <= length s}) :
  Lemma(slice (seq_four_to_seq_LE s) (n * 4) (n' * 4) ==
        seq_four_to_seq_LE (slice s n n'))
  =
  assert (equal (slice (seq_four_to_seq_LE s) (n * 4) (n' * 4))
                (seq_four_to_seq_LE (slice s n n')));
  ()

let slice_commutes_le_seq_quad32_to_bytes (s:seq quad32) (n:nat{n <= length s}) (n':nat{ n <= n' /\ n' <= length s}) :
  Lemma(slice (le_seq_quad32_to_bytes s) (n * 16) (n' * 16) ==
        le_seq_quad32_to_bytes (slice s n n'))
  =
  reveal_opaque le_seq_quad32_to_bytes_def;
  slice_commutes_seq_four_to_seq_LE s n n';
  assert (slice (seq_four_to_seq_LE s) (n * 4) (n' * 4) == seq_four_to_seq_LE (slice s n n'));
(*
  le_seq_quad32_to_bytes (slice s n n') == seq_four_to_seq_LE (seq_map (nat_to_four 8) (seq_four_to_seq_LE (slice s n n')));
                                        == seq_four_to_seq_LE (seq_map (nat_to_four 8) (slice (seq_four_to_seq_LE s) (n * 4) (n' * 4))
  slice (le_seq_quad32_to_bytes s) (n * 16) (n' * 16) 
  ==  slice (seq_four_to_seq_LE (seq_map (nat_to_four 8) (seq_four_to_seq_LE s))) (n * 16) (n' * 16)
  ==  seq_four_to_seq_LE (slice (seq_map (nat_to_four 8) (seq_four_to_seq_LE s)) (n * 4) (n' * 4))
*)
  slice_seq_map_commute (nat_to_four 8) (seq_four_to_seq_LE s) (n*4) (n'*4);

  let s_inner = (seq_map (nat_to_four 8) (seq_four_to_seq_LE s)) in
  slice_commutes_seq_four_to_seq_LE s_inner (n * 4) (n' * 4);
  ()

let slice_commutes_le_seq_quad32_to_bytes0 (s:seq quad32) (n:nat{n <= length s}) :
  Lemma(slice (le_seq_quad32_to_bytes s) 0 (n * 16) ==
        le_seq_quad32_to_bytes (slice s 0 n))
  =
  slice_commutes_le_seq_quad32_to_bytes s 0 n

(*
let seq_to_seq_four_LE (#a:Type) (x:seq a{length x % 4 == 0}) : seq (four a) =
  let f (n:nat{n < length x / 4}) = Mkfour
    (index x (n * 4)) (index x (n * 4 + 1)) (index x (n * 4 + 2)) (index x (n * 4 + 3))
    in
  init (length x / 4) f

let seq_nat8_to_seq_nat32_LE (x:seq nat8{length x % 4 == 0}) : seq nat32 =
  seq_map (four_to_nat 8) (seq_to_seq_four_LE x)
*)
let rec append_distributes_le_bytes_to_seq_quad32 (s1:seq nat8 { length s1 % 16 == 0 }) (s2:seq nat8 { length s2 % 16 == 0 }) :
  Lemma(le_bytes_to_seq_quad32 (s1 @| s2) == (le_bytes_to_seq_quad32 s1) @| (le_bytes_to_seq_quad32 s2))
  =
  reveal_opaque le_bytes_to_seq_quad32_def;
  let s1' = seq_nat8_to_seq_nat32_LE s1 in
  let s2' = seq_nat8_to_seq_nat32_LE s2 in
  // (le_bytes_to_seq_quad32 s1) @| (le_bytes_to_seq_quad32 s2)) 
  // =  { Definition of le_bytes_to_seq_quad32 }
  // seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE s1) @| seq_to_seq_four_LE (seq_nat8_to_seq_nat32_LE s2)  
  append_distributes_seq_to_seq_four_LE s1' s2';
  // = 
  // seq_to_seq_four_LE ((seq_nat8_to_seq_nat32_LE s1) @| (seq_nat8_to_seq_nat32_LE s2))
  append_distributes_seq_map (four_to_nat 8) (seq_to_seq_four_LE s1) (seq_to_seq_four_LE s2);
  // seq_to_seq_four_LE (seq_map (four_to_nat 8) ((seq_to_seq_four_LE s1) @| (seq_to_seq_four_LE s2)))
  append_distributes_seq_to_seq_four_LE s1 s2;
  // seq_to_seq_four_LE (seq_map (four_to_nat 8) (seq_to_seq_four_LE (s1 @| s2)))
  // le_bytes_to_seq_quad32 (s1 @| s2)
  ()
