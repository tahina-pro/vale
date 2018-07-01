module GCTR_i

open Opaque_s
open Words_s
open Types_s
open Types_i
open FStar.Mul
open FStar.Seq
open AES_s
open GCTR_s
open GCM_helpers_i
open FStar.Math.Lemmas
open Collections.Seqs_i

let make_gctr_plain_LE (p:seq nat8) : gctr_plain_LE = 
  if 4096 * length p < pow2_32 then p else createEmpty

let gctr_encrypt_block_offset (icb_BE:quad32) (plain_LE:quad32) (alg:algorithm) (key:aes_key_LE alg) (i:int) :
  Lemma (gctr_encrypt_block icb_BE plain_LE alg key i ==
         gctr_encrypt_block (inc32 icb_BE i) plain_LE alg key 0)
  =
  ()

let gctr_encrypt_empty (icb_BE:quad32) (plain_LE cipher_LE:seq quad32) (alg:algorithm) (key:aes_key_LE alg) : 
  Lemma (let plain = slice_work_around (le_seq_quad32_to_bytes plain_LE) 0 in
         let cipher = slice_work_around (le_seq_quad32_to_bytes cipher_LE) 0 in
         cipher = gctr_encrypt_LE icb_BE (make_gctr_plain_LE plain) alg key)
  =
  reveal_opaque le_bytes_to_seq_quad32_def;
  reveal_opaque gctr_encrypt_LE_def;
  let plain = slice_work_around (le_seq_quad32_to_bytes plain_LE) 0 in
  let cipher = slice_work_around (le_seq_quad32_to_bytes cipher_LE) 0 in
  assert (plain == createEmpty);
  assert (cipher == createEmpty);
  assert (length plain == 0);
  assert (make_gctr_plain_LE plain == createEmpty);
  let num_extra = (length (make_gctr_plain_LE plain)) % 16 in
  assert (num_extra == 0);
  let plain_quads_LE = le_bytes_to_seq_quad32 plain in
  let cipher_quads_LE = gctr_encrypt_recursive icb_BE plain_quads_LE alg key 0 in
  assert (equal plain_quads_LE createEmpty);     // OBSERVE
  assert (plain_quads_LE == createEmpty);
  assert (cipher_quads_LE == createEmpty);
  assert (equal (le_seq_quad32_to_bytes cipher_quads_LE) createEmpty);  // OBSERVEs
  ()

(*
let rec seq_map_i_indexed' (#a:Type) (#b:Type) (f:int->a->b) (s:seq a) (i:int) : 
  Tot (s':seq b { length s' == length s /\
                  (forall j . {:pattern index s' j} 0 <= j /\ j < length s ==> index s' j == f (i + j) (index s j))
                }) 
      (decreases (length s))
  =
  if length s = 0 then createEmpty
  else cons (f i (head s)) (seq_map_i_indexed f (tail s) (i + 1))

let rec test (icb_BE:quad32) (plain_LE:gctr_plain_internal_LE) 
	 (alg:algorithm) (key:aes_key_LE alg) (i:int) :
  Lemma (ensures
     (let gctr_encrypt_block_curried (j:int) (p:quad32) = gctr_encrypt_block icb_BE p alg key j in
     
      gctr_encrypt_recursive icb_BE plain_LE alg key i == seq_map_i_indexed' gctr_encrypt_block_curried plain_LE i)) 
     (decreases (length plain_LE))
  = 
  let gctr_encrypt_block_curried (j:int) (p:quad32) = gctr_encrypt_block icb_BE p alg key j in
  let g = gctr_encrypt_recursive icb_BE plain_LE alg key i in
  let s = seq_map_i_indexed' gctr_encrypt_block_curried plain_LE i in
  if length plain_LE = 0 then (
    assert(equal (g) (s));
    ()
  ) else (
    test icb_BE (tail plain_LE) alg key (i+1);
    assert (gctr_encrypt_recursive icb_BE (tail plain_LE) alg key (i+1) == seq_map_i_indexed' gctr_encrypt_block_curried (tail plain_LE) (i+1))
  )
*)

let aes_encrypt_BE (alg:algorithm) (key:aes_key_LE alg) (p_BE:quad32) =
  let p_LE = reverse_bytes_quad32 p_BE in
  aes_encrypt_LE alg key p_LE

let gctr_partial (alg:algorithm) (bound:nat) (plain cipher:seq quad32) (key:aes_key_LE alg) (icb:quad32) =
  let bound = min bound (min (length plain) (length cipher)) in
  forall j . {:pattern (index cipher j)} 0 <= j /\ j < bound ==>
    index cipher j == quad32_xor (index plain j) (aes_encrypt_BE alg key (inc32 icb j))
  
let rec gctr_encrypt_recursive_length (icb:quad32) (plain:gctr_plain_internal_LE)
                                      (alg:algorithm) (key:aes_key_LE alg) (i:int) : Lemma
  (requires True)
  (ensures length (gctr_encrypt_recursive icb plain alg key i) == length plain)
  (decreases %[length plain])
  [SMTPat (length (gctr_encrypt_recursive icb plain alg key i))]
  =
  if length plain = 0 then ()
  else gctr_encrypt_recursive_length icb (tail plain) alg key (i + 1)

#reset-options "--z3rlimit 40"
let rec gctr_encrypt_length (icb_BE:quad32) (plain:gctr_plain_LE)
                             (alg:algorithm) (key:aes_key_LE alg) :
  Lemma(length (gctr_encrypt_LE icb_BE plain alg key) == length plain)
  [SMTPat (length (gctr_encrypt_LE icb_BE plain alg key))]
  =
  reveal_opaque le_bytes_to_seq_quad32_def;
  reveal_opaque gctr_encrypt_LE_def;
  let num_extra = (length plain) % 16 in
  let result = gctr_encrypt_LE icb_BE plain alg key in
  if num_extra = 0 then (
    let plain_quads_LE = le_bytes_to_seq_quad32 plain in
    gctr_encrypt_recursive_length icb_BE plain_quads_LE alg key 0
  ) else ( 
    let full_bytes_len = (length plain) - num_extra in
    let full_blocks, final_block = split plain full_bytes_len in
    
    let full_quads_LE = le_bytes_to_seq_quad32 full_blocks in
    let final_quad_LE = le_bytes_to_quad32 (pad_to_128_bits final_block) in
    
    let cipher_quads_LE = gctr_encrypt_recursive icb_BE full_quads_LE alg key 0 in
    let final_cipher_quad_LE = gctr_encrypt_block icb_BE final_quad_LE alg key (full_bytes_len / 16) in
    
    let cipher_bytes_full_LE = le_seq_quad32_to_bytes cipher_quads_LE in
    let final_cipher_bytes_LE = slice (le_quad32_to_bytes final_cipher_quad_LE) 0 num_extra in
    
    gctr_encrypt_recursive_length icb_BE full_quads_LE alg key 0;
    assert (length result == length cipher_bytes_full_LE + length final_cipher_bytes_LE);
    assert (length cipher_quads_LE == length full_quads_LE);
    assert (length cipher_bytes_full_LE == 16 * length cipher_quads_LE);
    assert (16 * length full_quads_LE == length full_blocks);
    assert (length cipher_bytes_full_LE == length full_blocks);
    ()
  )
#reset-options

//#reset-options "--use_two_phase_tc true" // Needed so that indexing cipher and plain knows that their lengths are equal
let rec gctr_indexed_helper (icb:quad32) (plain:gctr_plain_internal_LE)
                            (alg:algorithm) (key:aes_key_LE alg) (i:int) : Lemma
  (requires True)
  (ensures (let cipher = gctr_encrypt_recursive icb plain alg key i in
            length cipher == length plain /\
           (forall j . {:pattern index cipher j} 0 <= j /\ j < length plain ==>
           index cipher j == quad32_xor (index plain j) (aes_encrypt_BE alg key (inc32 icb (i + j)) ))))
  (decreases %[length plain])
=
  if length plain = 0 then ()
  else
      let tl = tail plain in
      let cipher = gctr_encrypt_recursive icb plain alg key i in
      let r_cipher = gctr_encrypt_recursive icb tl alg key (i+1) in
      let helper (j:int) :
        Lemma ((0 <= j /\ j < length plain) ==> (index cipher j == quad32_xor (index plain j) (aes_encrypt_BE alg key (inc32 icb (i + j)) )))
        =
        if 0 < j && j < length plain then (
          gctr_indexed_helper icb tl alg key (i+1);
          assert(index r_cipher (j-1) == quad32_xor (index tl (j-1)) (aes_encrypt_BE alg key (inc32 icb (i + 1 + j - 1)) )) // OBSERVE
        ) else ()
      in
      FStar.Classical.forall_intro helper

let rec gctr_indexed (icb:quad32) (plain:gctr_plain_internal_LE)
                     (alg:algorithm) (key:aes_key_LE alg) (cipher:seq quad32) : Lemma
  (requires  length cipher == length plain /\
             (forall i . {:pattern index cipher i} 0 <= i /\ i < length cipher ==>
             index cipher i == quad32_xor (index plain i) (aes_encrypt_BE alg key (inc32 icb i) )))
  (ensures  cipher == gctr_encrypt_recursive icb plain alg key 0)
=
  gctr_indexed_helper icb plain alg key 0;
  let c = gctr_encrypt_recursive icb plain alg key 0 in
  assert(equal cipher c)  // OBSERVE: Invoke extensionality lemmas


let gctr_partial_completed (alg:algorithm) (plain cipher:seq quad32) (key:aes_key_LE alg) (icb:quad32) : Lemma
  (requires length plain == length cipher /\
            256 * (length plain) < pow2_32 /\
            gctr_partial alg (length cipher) plain cipher key icb)
  (ensures cipher == gctr_encrypt_recursive icb plain alg key 0)
  =
  gctr_indexed icb plain alg key cipher;
  ()

let gctr_partial_to_full_basic (icb_BE:quad32) (plain:seq quad32) (alg:algorithm) (key:aes_key_LE alg) (cipher:seq quad32) : Lemma
  (requires (cipher == gctr_encrypt_recursive icb_BE plain alg key 0) /\
            (4096 * (length plain) * 16 < pow2_32))
  (ensures le_seq_quad32_to_bytes cipher == gctr_encrypt_LE icb_BE (le_seq_quad32_to_bytes plain) alg key)
  =
  reveal_opaque gctr_encrypt_LE_def;
  let p = le_seq_quad32_to_bytes plain in
  assert (length p % 16 == 0);
  let plain_quads_LE = le_bytes_to_seq_quad32 p in
  let cipher_quads_LE = gctr_encrypt_recursive icb_BE plain_quads_LE alg key 0 in
  let cipher_bytes = le_seq_quad32_to_bytes cipher_quads_LE in
  le_bytes_to_seq_quad32_to_bytes plain;
  ()


(*
Want to show that:
   slice (le_seq_quad32_to_bytes (buffer128_as_seq(mem, out_b))) 0 num_bytes
   ==
   gctr_encrypt_LE icb_BE (slice (le_seq_quad32_to_bytes (buffer128_as_seq(mem, in_b))) 0 num_bytes) ...

We know that 
   slice (buffer128_as_seq(mem, out_b) 0 num_blocks
   ==
   gctr_encrypt_recursive icb_BE (slice buffer128_as_seq(mem, in_b) 0 num_blocks) ...

And we know that:
  get_mem out_b num_blocks 
  ==
  gctr_encrypt_block(icb_BE, (get_mem inb num_blocks), alg, key, num_blocks);


Internally gctr_encrypt_LE will compute:
  full_blocks, final_block = split (slice (le_seq_quad32_to_bytes (buffer128_as_seq(mem, in_b))) 0 num_bytes) (num_blocks * 16)

  We'd like to show that
  Step1:  le_bytes_to_seq_quad32 full_blocks == slice buffer128_as_seq(mem, in_b) 0 num_blocks
    and 
  Step2:  final_block == slice (le_quad32_to_bytes (get_mem inb num_blocks)) 0 num_extra

  Then we need to break down the byte-level effects of gctr_encrypt_block to show that even though the
  padded version of final_block differs from (get_mem inb num_blocks), after we slice it at the end,
  we end up with the same value
*)


let step1 (p:seq quad32) (num_bytes:nat{ num_bytes < 16 * length p }) : Lemma
  (let num_extra = num_bytes % 16 in
   let num_blocks = num_bytes / 16 in
   let full_blocks, final_block = split (slice (le_seq_quad32_to_bytes p) 0 num_bytes) (num_blocks * 16) in
   let full_quads_LE = le_bytes_to_seq_quad32 full_blocks in
   let p_prefix = slice p 0 num_blocks in
   p_prefix == full_quads_LE)
  =
  let num_extra = num_bytes % 16 in
  let num_blocks = num_bytes / 16 in
  let full_blocks, final_block = split (slice (le_seq_quad32_to_bytes p) 0 num_bytes) (num_blocks * 16) in
  let full_quads_LE = le_bytes_to_seq_quad32 full_blocks in
  let p_prefix = slice p 0 num_blocks in
  assert (length full_blocks == num_blocks * 16);
  assert (full_blocks == slice (slice (le_seq_quad32_to_bytes p) 0 num_bytes) 0 (num_blocks * 16));
  assert (full_blocks == slice (le_seq_quad32_to_bytes p) 0 (num_blocks * 16));
  slice_commutes_le_seq_quad32_to_bytes0 p num_blocks;
  assert (full_blocks == le_seq_quad32_to_bytes (slice p 0 num_blocks));
  le_bytes_to_seq_quad32_to_bytes (slice p 0 num_blocks);
  assert (full_quads_LE == (slice p 0 num_blocks));
  ()

let quad32_xor_bytewise (q q' r:quad32) (n:nat{ n <= 16 }) : Lemma
  (requires (let q_bytes  = le_quad32_to_bytes q in
             let q'_bytes = le_quad32_to_bytes q' in
             slice q_bytes 0 n == slice q'_bytes 0 n))             
  (ensures (let q_bytes  = le_quad32_to_bytes q in
            let q'_bytes = le_quad32_to_bytes q' in
            let qr_bytes  = le_quad32_to_bytes (quad32_xor q r) in 
            let q'r_bytes = le_quad32_to_bytes (quad32_xor q' r) in                      
            slice qr_bytes 0 n == slice q'r_bytes 0 n))
  =
  admit()       //////////////////////////////////////////////////////////////////////////////// TODO!!!


let slice_pad_to_128_bits (s:seq nat8 {  0 < length s /\ length s < 16 }) :
  Lemma(slice (pad_to_128_bits s) 0 (length s) == s)
  =
  assert (length s % 16 == length s);
  assert (equal s (slice (pad_to_128_bits s) 0 (length s)));
  ()

let step2 (s:seq nat8 {  0 < length s /\ length s < 16 }) (q:quad32) (icb_BE:quad32) (alg:algorithm) (key:aes_key_LE alg) (i:int):
  Lemma(let q_bytes = le_quad32_to_bytes q in
        let q_bytes_prefix = slice q_bytes 0 (length s) in
        let q_cipher = gctr_encrypt_block icb_BE q alg key i in
        let q_cipher_bytes = slice (le_quad32_to_bytes q_cipher) 0 (length s) in
        let s_quad = le_bytes_to_quad32 (pad_to_128_bits s) in
        let s_cipher = gctr_encrypt_block icb_BE s_quad alg key i in
        let s_cipher_bytes = slice (le_quad32_to_bytes s_cipher) 0 (length s) in       
        s == q_bytes_prefix ==> s_cipher_bytes == q_cipher_bytes)
  = 
  let q_bytes = le_quad32_to_bytes q in
  let q_bytes_prefix = slice q_bytes 0 (length s) in
  let q_cipher = gctr_encrypt_block icb_BE q alg key i in
  let q_cipher_bytes = slice (le_quad32_to_bytes q_cipher) 0 (length s) in
  let s_quad = le_bytes_to_quad32 (pad_to_128_bits s) in
  let s_cipher = gctr_encrypt_block icb_BE s_quad alg key i in
  let s_cipher_bytes = slice (le_quad32_to_bytes s_cipher) 0 (length s) in 
  let enc_ctr = aes_encrypt_LE alg key (reverse_bytes_quad32 (inc32 icb_BE i)) in
  let icb_LE = reverse_bytes_quad32 (inc32 icb_BE i) in
  
  if s = q_bytes_prefix then (
     //  s_cipher_bytes = slice (le_quad32_to_bytes s_cipher) 0 (length s)
     //                 = slice (le_quad32_to_bytes (gctr_encrypt_block icb_BE s_quad alg key i)) 0 (length s)
     //                 = slice (le_quad32_to_bytes (gctr_encrypt_block icb_BE (le_bytes_to_quad32 (pad_to_128_bits s)) alg key i)) 0 (length s)

     // q_cipher_bytes  = gctr_encrypt_block icb_BE q alg key i
    le_quad32_to_bytes_to_quad32 (pad_to_128_bits s);
    slice_pad_to_128_bits s;
    quad32_xor_bytewise q (le_bytes_to_quad32 (pad_to_128_bits s)) (aes_encrypt_LE alg key icb_LE) (length s);
    //assert (equal s_cipher_bytes q_cipher_bytes);
    ()
  ) else
    ();
  ()

#reset-options "--z3rlimit 30" 
open FStar.Seq.Properties

let gctr_partial_to_full_advanced (icb_BE:quad32) (plain:seq quad32) (cipher:seq quad32) (alg:algorithm) (key:aes_key_LE alg) (num_bytes:nat) : Lemma
  (requires (1 <= num_bytes /\ 
             num_bytes < 16 * length plain /\
             16 * (length plain - 1) < num_bytes /\
             num_bytes % 16 <> 0 /\ 4096 * num_bytes < pow2_32 /\
             length plain == length cipher /\
             (let num_blocks = num_bytes / 16 in
              slice cipher 0 num_blocks == gctr_encrypt_recursive icb_BE (slice plain 0 num_blocks) alg key 0 /\
              index cipher num_blocks == gctr_encrypt_block icb_BE (index plain num_blocks) alg key num_blocks)))
  (ensures (let plain_bytes = slice (le_seq_quad32_to_bytes plain) 0 num_bytes in
            let cipher_bytes = slice (le_seq_quad32_to_bytes cipher) 0 num_bytes in
            cipher_bytes == gctr_encrypt_LE icb_BE plain_bytes alg key))
  =
  reveal_opaque gctr_encrypt_LE_def;
  let num_blocks = num_bytes / 16 in
  let plain_bytes = slice (le_seq_quad32_to_bytes plain) 0 num_bytes in
  let cipher_bytes = slice (le_seq_quad32_to_bytes cipher) 0 num_bytes in
  step1 plain num_bytes;
  let s = slice (le_seq_quad32_to_bytes plain) (num_blocks * 16) num_bytes in
  let final_p = index plain num_blocks in
  step2 s final_p icb_BE alg key num_blocks;

  let num_extra = num_bytes % 16 in
  let full_bytes_len = num_bytes - num_extra in
  let full_blocks, final_block = split plain_bytes full_bytes_len in
  assert (full_bytes_len % 16 == 0);
  assert (length full_blocks == full_bytes_len);
  let full_quads_LE = le_bytes_to_seq_quad32 full_blocks in
  let final_quad_LE = le_bytes_to_quad32 (pad_to_128_bits final_block) in
  let cipher_quads_LE = gctr_encrypt_recursive icb_BE full_quads_LE alg key 0 in
  let final_cipher_quad_LE = gctr_encrypt_block icb_BE final_quad_LE alg key (full_bytes_len / 16) in
  assert (cipher_quads_LE == slice cipher 0 num_blocks);   // LHS quads
  let cipher_bytes_full_LE = le_seq_quad32_to_bytes cipher_quads_LE in
  let final_cipher_bytes_LE = slice (le_quad32_to_bytes final_cipher_quad_LE) 0 num_extra in

  assert (le_seq_quad32_to_bytes cipher_quads_LE == le_seq_quad32_to_bytes (slice cipher 0 num_blocks)); // LHS bytes

  assert (length s == num_extra);
  let q_prefix = slice (le_quad32_to_bytes final_p) 0 num_extra in
  le_seq_quad32_to_bytes_tail_prefix plain num_bytes;
  assert (q_prefix == s);

  assert(final_cipher_bytes_LE == slice (le_quad32_to_bytes (index cipher num_blocks)) 0 num_extra); // RHS bytes

  le_seq_quad32_to_bytes_tail_prefix cipher num_bytes;
  assert (slice (le_quad32_to_bytes (index cipher num_blocks)) 0 num_extra ==
          slice (le_seq_quad32_to_bytes cipher) (num_blocks * 16) num_bytes);

  slice_commutes_le_seq_quad32_to_bytes0 cipher num_blocks;
  assert (le_seq_quad32_to_bytes (slice cipher 0 num_blocks) == slice (le_seq_quad32_to_bytes cipher) 0 (num_blocks * 16));


  assert (slice (slice (le_seq_quad32_to_bytes cipher) (num_blocks * 16) (length cipher * 16)) 0 num_extra ==
          slice (le_seq_quad32_to_bytes cipher) (num_blocks * 16) num_bytes);
  slice_append_adds (le_seq_quad32_to_bytes cipher) (num_blocks * 16) num_bytes;
  assert (slice (le_seq_quad32_to_bytes cipher) 0 (num_blocks * 16) @| 
          slice (le_seq_quad32_to_bytes cipher) (num_blocks * 16) num_bytes ==
          slice (le_seq_quad32_to_bytes cipher) 0 num_bytes);
  assert (cipher_bytes == (le_seq_quad32_to_bytes (slice cipher 0 num_blocks)) @| slice (le_quad32_to_bytes (index cipher num_blocks)) 0 num_extra);
  ()


let gctr_encrypt_one_block (icb_BE plain:quad32) (alg:algorithm) (key:aes_key_LE alg) :
  Lemma(gctr_encrypt_LE icb_BE (le_quad32_to_bytes plain) alg key =
        le_seq_quad32_to_bytes (create 1 (quad32_xor plain (aes_encrypt_BE alg key icb_BE)))) =
  reveal_opaque gctr_encrypt_LE_def;
  assert(inc32 icb_BE 0 == icb_BE);
  let encrypted_icb = aes_encrypt_BE alg key icb_BE in
  let p = le_quad32_to_bytes plain in
  let plain_quads_LE = le_bytes_to_seq_quad32 p in
  let p_seq = create 1 plain in
  assert (length p == 16);
  le_bytes_to_seq_quad32_to_bytes_one_quad plain;
  assert (p_seq == plain_quads_LE);
  let cipher_quads_LE = gctr_encrypt_recursive icb_BE plain_quads_LE alg key 0 in  
  assert (cipher_quads_LE == cons (gctr_encrypt_block icb_BE (head plain_quads_LE) alg key 0) (gctr_encrypt_recursive icb_BE (tail plain_quads_LE) alg key (1)));
  assert (head plain_quads_LE == plain);

  assert (gctr_encrypt_block icb_BE (head plain_quads_LE) alg key 0 == 
          (let icb_LE = reverse_bytes_quad32 (inc32 icb_BE 0) in
           quad32_xor (head plain_quads_LE) (aes_encrypt_LE alg key icb_LE)));
  assert (quad32_xor plain (aes_encrypt_LE alg key (reverse_bytes_quad32 icb_BE))
          ==
          (let icb_LE = reverse_bytes_quad32 (inc32 icb_BE 0) in
           quad32_xor (head plain_quads_LE) (aes_encrypt_LE alg key icb_LE)));
  assert (gctr_encrypt_block icb_BE (head plain_quads_LE) alg key 0 == quad32_xor plain (aes_encrypt_LE alg key (reverse_bytes_quad32 icb_BE)));
  assert (gctr_encrypt_block icb_BE (head plain_quads_LE) alg key 0 == quad32_xor plain (aes_encrypt_BE alg key icb_BE));
  assert (gctr_encrypt_block icb_BE (head plain_quads_LE) alg key 0 == quad32_xor plain encrypted_icb);
  assert(gctr_encrypt_recursive icb_BE (tail p_seq) alg key 1 == createEmpty);   // OBSERVE
  //assert(gctr_encrypt_LE icb p alg key == cons (quad32_xor plain encrypted_icb) createEmpty);
  let x = quad32_xor plain encrypted_icb in
  append_empty_r (create 1 x);                 // This is the missing piece
  ()
