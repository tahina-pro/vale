module GCM_helpers_i

open Words_s
open Words.Seq_s
open Types_s
open Types_i
open FStar.Mul
open FStar.Seq
open AES_s 
open GCTR_s
open FStar.Math.Lemmas
open Collections.Seqs_i

let bytes_to_quad_size (num_bytes:nat) =
  ((num_bytes + 15) / 16)

val slice_work_around (#a:Type) (s:seq a) (i:int) : Pure (seq a)
  (requires True)
  (ensures fun s' -> 0 <= i && i <= length s ==> s' == slice s 0 i)

val index_work_around_quad32 (s:seq quad32) (i:int) : Pure quad32
  (requires True)
  (ensures fun s' -> 0 <= i && i < length s ==> s' == index s i)

val bytes_to_quad_size_no_extra_bytes (num_bytes:nat) : Lemma 
  (requires num_bytes % 16 == 0)
  (ensures bytes_to_quad_size num_bytes = num_bytes / 16)

val no_extra_bytes_helper (s:seq quad32) (num_bytes:int) : Lemma
  (requires 0 <= num_bytes /\
            num_bytes % 16 == 0 /\
            length s == bytes_to_quad_size num_bytes)
  (ensures slice (le_seq_quad32_to_bytes s) 0 num_bytes == le_seq_quad32_to_bytes s /\
           slice_work_around s (num_bytes / 16) == s)

val le_seq_quad32_to_bytes_tail_prefix (s:seq quad32) (num_bytes:nat) : Lemma
  (requires (1 <= num_bytes /\ 
             num_bytes < 16 * length s /\
             16 * (length s - 1) < num_bytes /\
             num_bytes % 16 <> 0))
  (ensures (let num_extra = num_bytes % 16 in
            let num_blocks = num_bytes / 16 in
            let x  = slice (le_seq_quad32_to_bytes s) (num_blocks * 16) num_bytes in
            let x' = slice (le_quad32_to_bytes (index s num_blocks)) 0 num_extra in
            x == x'))

val pad_to_128_bits_le_quad32_to_bytes (s:seq quad32) (num_bytes:int) : Lemma
  (requires 1 <= num_bytes /\ 
             num_bytes < 16 * length s /\
             16 * (length s - 1) < num_bytes /\
             num_bytes % 16 <> 0 /\
             length s == bytes_to_quad_size num_bytes)
  (ensures (let num_blocks = num_bytes / 16 in
            let full_quads,final_quads = split s num_blocks in
            length final_quads == 1 /\
            (let final_quad = index final_quads 0 in
             pad_to_128_bits (slice (le_seq_quad32_to_bytes s) 0 num_bytes)
             ==
             le_seq_quad32_to_bytes full_quads @| pad_to_128_bits (slice (le_quad32_to_bytes final_quad) 0 (num_bytes % 16)))))

val pad_to_128_bits_lower (q:quad32) (num_bytes:int) : Lemma
  (requires 1 <= num_bytes /\ num_bytes < 8)
  (ensures (let new_lo = (lo64 q) % pow2 (num_bytes * 8) in
            new_lo < pow2_64 /\
            (let q' = insert_nat64 (insert_nat64 q 0 1) new_lo 0 in
             q' == le_bytes_to_quad32 (pad_to_128_bits (slice (le_quad32_to_bytes q) 0 num_bytes)))))
            
val pad_to_128_bits_upper (q:quad32) (num_bytes:int) : Lemma
  (requires 8 <= num_bytes /\ num_bytes < 16)
  (ensures (let new_hi = (hi64 q) % pow2 ((num_bytes - 8) * 8) in
            new_hi < pow2_64 /\
            (let q' = insert_nat64 q new_hi 1 in
             q' == le_bytes_to_quad32 (pad_to_128_bits (slice (le_quad32_to_bytes q) 0 num_bytes)))))
                   
  
