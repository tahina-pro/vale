module GF128_i
open TypesNative_i

let lemma_to_of_quad32 q =
  reveal_of_quad32 q;
  reveal_to_quad32 (of_quad32 q);
  let a = of_quad32 q in
  let Quad32 q0 q1 q2 q3 = q in
  let Quad32 q0' q1' q2' q3' = to_quad32 a in
  lemma_index a;
  lemma_reverse_define_all ();
  let s0 = UInt.to_vec #32 q0 in
  let s1 = UInt.to_vec #32 q1 in
  let s2 = UInt.to_vec #32 q2 in
  let s3 = UInt.to_vec #32 q3 in
  let s0' = UInt.to_vec #32 q0' in
  let s1' = UInt.to_vec #32 q1' in
  let s2' = UInt.to_vec #32 q2' in
  let s3' = UInt.to_vec #32 q3' in
  assert (equal s0 s0');
  assert (equal s1 s1');
  assert (equal s2 s2');
  assert (equal s3 s3');
  ()

let lemma_of_to_quad32 a =
  reveal_to_quad32 a;
  reveal_of_quad32 (to_quad32 a);
  lemma_index_all ();
  lemma_reverse_define_all ();
  lemma_equal a (of_quad32 (to_quad32 a))

let lemma_shift_left_1 a =
  reveal_to_quad32 a;
  reveal_to_quad32 (shift a 1);
  lemma_zero_nth 32;
  lemma_ishl_nth_all 32;
  lemma_ishr_nth_all 32;
  lemma_ixor_nth_all 32;
  lemma_index_all ();
  lemma_shift_define a 1;
  lemma_reverse_define_all ();
  lemma_quad32_vec_equal (to_quad32 (shift a 1)) (quad32_shift_left_1 (to_quad32 a));
  ()

#reset-options "--z3rlimit 10"
let lemma_shift_2_left_1 lo hi =
  let n = monomial 128 in
  let a = hi *. n +. lo in
  let a' = shift a 1 in
  let (qlo', qhi') = quad32_shift_2_left_1 (to_quad32 lo) (to_quad32 hi) in
  reveal_to_quad32 lo;
  reveal_to_quad32 hi;
  reveal_to_quad32 (a' %. n);
  reveal_to_quad32 (a' /. n);
  lemma_zero_nth 32;
  lemma_ishl_nth_all 32;
  lemma_ishr_nth_all 32;
  lemma_ixor_nth_all 32;
  lemma_index_all ();
  lemma_shift_define a 1;
  lemma_add_define_all ();
  lemma_reverse_define_all ();
  lemma_div_mod a' n;
  lemma_shift_is_mul hi 128;
  lemma_shift_define hi 128;
  lemma_shift_is_mul (a' /. n) 128;
  let lemma_lo () : Lemma (qlo' == to_quad32 (a' %. n)) =
    lemma_shift_define (a' /. n) 128;
    lemma_quad32_vec_equal qlo' (to_quad32 (a' %. n))
    in
  let lemma_hi () : Lemma (qhi' == to_quad32 (a' /. n)) =
    lemma_shift_define_forward (a' /. n) 128;
    lemma_quad32_vec_equal qhi' (to_quad32 (a' /. n))
    in
  lemma_lo ();
  lemma_hi ();
  ()
#reset-options

let lemma_gf128_degree () =
  lemma_add_define_all ();
  lemma_monomial_define 128;
  lemma_of_list_degree [true; true; true; false; false; false; false; true];
  lemma_degree_is (monomial 128) 128;
  lemma_degree_is gf128_modulus 128;
  ()

let lemma_gf128_mul a b c d n =
  let m = monomial n in
  let ab = a *. m +. b in
  let cd = c *. m +. d in
  let ac = a *. c in
  let ad = a *. d in
  let bc = b *. c in
  let bd = b *. d in
  let adh = ad /. m in
  let bch = bc /. m in
  let adl = ad %. m in
  let bcl = bc %. m in
  // ab *. cd
  // (a *. m +. b) *. (c *. m +. d)
  lemma_mul_distribute_right (a *. m +. b) (c *. m) d;
  lemma_mul_distribute_left (a *. m) b (c *. m);
  lemma_mul_distribute_left (a *. m) b d;
  // ((a *. m) *. (c *. m) +. b *. (c *. m)) +. ((a *. m) *. d +. b *. d);
  lemma_mul_associate b c m;
  lemma_mul_associate a m d;
  lemma_mul_commute m d;
  lemma_mul_associate a d m;
  lemma_mul_associate a m (c *. m);
  lemma_mul_associate m c m;
  lemma_mul_commute c m;
  lemma_mul_associate c m m;
  lemma_mul_associate a c (m *. m);
  // (ac *. (m *. m) +. bc *. m) +. (ad *. m +. bd)
  lemma_div_mod ad m;
  lemma_div_mod bc m;
  // (ac *. (m *. m) +. (bch *. m +. bcl) *. m) +. ((adh *. m +. adl) *. m +. bd)
  lemma_mul_distribute_left (bch *. m) bcl m;
  lemma_mul_distribute_left (adh *. m) adl m;
  // (ac *. (m *. m) +. (bch *. m *. m +. bcl *. m)) +. ((adh *. m *. m +. adl *. m) +. bd)
  lemma_mul_associate bch m m;
  lemma_mul_associate adh m m;
  // (ac *. (m *. m) +. (bch *. (m *. m) +. bcl *. m)) +. ((adh *. (m *. m) +. adl *. m) +. bd)
  assert (ab *. cd == (ac *. (m *. m) +. (bch *. (m *. m) +. bcl *. m)) +. ((adh *. (m *. m) +. adl *. m) +. bd));
  lemma_add_define_all ();
  lemma_equal (ab *. cd) ((ac *. (m *. m) +. bch *. (m *. m) +. adh *. (m *. m)) +. (bcl *. m +. adl *. m +. bd));
  // (ac *. (m *. m) +. bch *. (m *. m) +. adh *. (m *. m)) +. (bcl *. m +. adl *. m +. bd)
  lemma_mul_distribute_left ac bch (m *. m);
  lemma_mul_distribute_left (ac +. bch) adh (m *. m);
  // (ac +. bch +. adh) *. (m *. m) +. (bcl *. m +. adl *. m +. bd)
  lemma_mul_monomials n n;
  lemma_shift_is_mul (ac +. bch +. adh) (n + n);
  // shift (ac +. bch +. adh) (n + n) +. (bcl *. m +. adl *. m +. bd)

  // ((((ach *. m) *. (m *. m)) +. acl *. (m *. m)) +. (bch *. (m *. m) +. bcl *. m)) +. ((adh *. (m *. m) +. adl *. m) +. (bdh *. m +. bdl))
//  assert (ab *. cd == ((((ach *. m) *. (m *. m)) +. acl *. (m *. m)) +. (bch *. (m *. m) +. bcl *. m)) +. ((adh *. (m *. m) +. adl *. m) +. (bdh *. m +. bdl)));

//  lemma_equal (ab *. cd) (((ach *. m) *. (m *. m) +. (acl *. (m *. m) +. bch *. (m *. m) +. adh *. (m *. m))) +. (bcl *. m +. adl *. m +. bdh *. m +. bdl));
  // ((ach *. m) *. (m *. m) +. (acl *. (m *. m) +. bch *. (m *. m) +. adh *. (m *. m))) +. (bcl *. m +. adl *. m +. bdh *. m +. bdl)
//  lemma_mul_distribute_left acl bch (m *. m);
//  lemma_mul_distribute_left (acl +. bch) adh (m *. m);
//  lemma_mul_distribute_left bcl adl m;
//  lemma_mul_distribute_left (bcl +. adl) bdh m;
//  lemma_mul_distribute_left (ach *. m) (acl +. bch +. adh) (m *. m);
  // ((ach *. m) +. (acl +. bch +. adh)) *. (m *. m) +. ((bcl +. adl +. bdh) *. m +. bdl)
  ()

let lemma_gf128_reduce a b g n h =
  let ab = a *. b in
  let d = ab /. n in
  let m = ab %. n in
  let dh = d *. h in
  let d' = dh /. n in
  let m' = dh %. n in
  lemma_div_mod ab n;
  lemma_div_mod dh n;
  // ab == d *. n +. m
  // dh == d' *. n +. m'

  // ab % g
  // (d *. n +. m) % g
  lemma_add_define_all ();
  lemma_zero_define ();
  lemma_equal n (g +. h);
  // (d *. (g +. h) +. m) % g
  lemma_mul_distribute_right d g h;
  // (d *. g +. dh +. m) % g
  // (d *. g +. (d' *. n +. m') + m) % g
  // (d *. g +. (d' *. (g +. h) +. m') + m) % g
  lemma_mul_distribute_right d' g h;
  // (d *. g +. (d' *. g +. d' *. h +. m') + m) % g
  lemma_equal ab ((d *. g +. d' *. g) +. (d' *. h +. m' +. m));
  lemma_mul_distribute_left d d' g;
  // ((d +. d') *. g +. (d' *. h +. m' +. m)) % g
  lemma_mod_distribute ((d +. d') *. g) (d' *. h +. m' +. m) g;
  lemma_div_mod_exact (d +. d') g;
  lemma_equal (ab %. g) ((d' *. h +. m' +. m) %. g);
  // (d' *. h +. m' +. m) % g
  lemma_mod_small (d' *. h +. m' +. m) g;
  // d' *. h +. m' +. m
  ()