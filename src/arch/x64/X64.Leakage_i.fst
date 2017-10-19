module X64.Leakage_i
open X64.Machine_s
open X64.Semantics_s
open X64.Taint_Semantics_s
open X64.Leakage_s
open X64.Leakage_Helpers_i
open X64.Leakage_Ins_i

open FStar.Tactics

#reset-options "--initial_ifuel 2 --max_ifuel 2 --initial_fuel 4 --using_facts_from '* -FStar.Reflection -FStar.Tactics'"
let combine_reg_taints regs1 regs2 =
    fun x -> merge_taint (regs1 x) (regs2 x)

let combine_taint_states (ts:taintState) (ts1:taintState) (ts2:taintState) =
  TaintState (combine_reg_taints ts1.regTaint ts2.regTaint) (merge_taint ts1.flagsTaint ts2.flagsTaint)
  
let rec check_if_block_consumes_fixed_time (block:tainted_codes) (fuel:nat) (ts:taintState) : bool * taintState =
  match block with
  | [] -> true, ts
  | hd::tl -> let fixedTime, ts_int = check_if_code_consumes_fixed_time hd fuel ts in
    if (not fixedTime) then fixedTime, ts_int
    else check_if_block_consumes_fixed_time tl fuel ts_int
    

and check_if_code_consumes_fixed_time (code:tainted_code) (fuel:nat) (ts:taintState) : bool * taintState =
  match code with
  | Ins ins -> check_if_ins_consumes_fixed_time ins fuel ts
  
  | Block block -> check_if_block_consumes_fixed_time block fuel ts

  | IfElse ifCond ifTrue ifFalse ->
    let cond_taint = ifCond.ot in
    let o1 = operand_taint (get_fst_ocmp ifCond.o) ts in
    let o2 = operand_taint (get_snd_ocmp ifCond.o) ts in
    let predTaint = merge_taint (merge_taint o1 o2) cond_taint in
    if (Secret? predTaint) then (false, ts)
    else
      let o1Public = operand_does_not_use_secrets (get_fst_ocmp ifCond.o) ts in
      if (not o1Public) then (false, ts)
      else
      let o2Public = operand_does_not_use_secrets (get_snd_ocmp ifCond.o) ts in
      if (not o2Public) then (false, ts)
      else
      let validIfTrue, tsIfTrue = check_if_code_consumes_fixed_time ifTrue fuel ts in
      if (not validIfTrue) then (false, ts)
      else
      let validIfFalse, tsIfFalse = check_if_code_consumes_fixed_time ifFalse fuel ts in
      if (not validIfFalse) then (false, ts)
      else
      (true, combine_taint_states ts tsIfTrue tsIfFalse)
     
  | _ -> false, ts


(*
and check_if_loop_consumes_fixed_time (pred:tainted_ocmp) (body:tainted_code) (ts:taintState) : bool * taintState =
  let cond_taint = pred.ot in
  let o1 = operand_taint (get_fst_ocmp pred.o) ts in
  let o2 = operand_taint (get_snd_ocmp pred.o) ts in
  let predTaint = merge_taint (merge_taint o1 o2) cond_taint in

  if (Secret? predTaint) then false, ts
  else
    let o1Public = operand_does_not_use_secrets (get_fst_ocmp pred.o) ts in
    if (not o1Public) then (false, ts)
    else
    let o2Public = operand_does_not_use_secrets (get_snd_ocmp pred.o) ts in
    if (not o2Public) then (false, ts)
    else
    let fixedTime, next_ts = check_if_code_consumes_fixed_time body ts in
    let combined_ts = combine_taint_states ts ts next_ts in
    if (combined_ts = ts) then true, combined_ts
    else check_if_loop_consumes_fixed_time pred body combined_ts
*)
  

val lemma_equal_eval_isConstant_aux: (code1: tainted_code) -> (code2:tainted_code) -> (fuel:nat) -> (ts:taintState) -> (ts':taintState) -> (s1 : traceState) -> (s2:traceState) -> Lemma ((forall s. taint_eval_code code1 fuel s == taint_eval_code code2 fuel s) ==> 
  isConstantTimeGivenStates code1 fuel ts s1 s2 /\ isExplicitLeakageFreeGivenStates code1 fuel ts ts' s1 s2 ==> isConstantTimeGivenStates code2 fuel ts s1 s2 /\ isExplicitLeakageFreeGivenStates code2 fuel ts ts' s1 s2)
  
let lemma_equal_eval_isConstant_aux code1 code2 fuel ts ts' s1 s2 = ()

val lemma_equal_eval_isConstant: (code1: tainted_code) -> (code2:tainted_code) -> (fuel:nat) -> (ts:taintState) -> (ts':taintState) -> Lemma ((forall s. taint_eval_code code1 s == taint_eval_code code2 s) ==> 
  isConstantTime code1 fuel ts /\ isLeakageFree code1 fuel ts ts' ==> isConstantTime code2 fuel ts /\ isLeakageFree code2 fuel ts ts')
  
let lemma_equal_eval_isConstant code1 code2 fuel ts ts' = FStar.Classical.forall_intro_2 (lemma_equal_eval_isConstant_aux code1 code2 fuel ts ts')

val monotone_ok_eval: (code:tainted_code) -> (fuel:nat) -> (s:traceState) -> Lemma
 (requires True)
 (ensures (let s' = taint_eval_code code fuel s in
    Some? s' /\ (Some?.v s').state.ok ==> s.state.ok))
 (decreases %[code; 0])

val monotone_ok_eval_block: (codes:tainted_codes) -> (fuel:nat) -> (s:traceState) -> Lemma
 (requires True)
 (ensures (let s' = taint_eval_codes codes fuel s in
    Some? s' /\ (Some?.v s').state.ok ==> s.state.ok))
 (decreases %[codes;1])

#set-options "--z3rlimit 20"
let rec monotone_ok_eval code fuel s = match code with
  | Ins ins -> ()
  | Block block -> monotone_ok_eval_block block fuel s
  | IfElse ifCond ifTrue ifFalse ->
    let st, b = taint_eval_ocmp s ifCond in
    let st = {st with trace=BranchPredicate(b)::s.trace} in
    if b then monotone_ok_eval ifTrue fuel st else monotone_ok_eval ifFalse fuel st
  | While _ _ -> admit()

and monotone_ok_eval_block block fuel s =
  match block with
  | [] -> ()
  | hd :: tl -> 
    let s' = taint_eval_code hd fuel s in
    if None? s' then () else
    monotone_ok_eval_block tl fuel (Some?.v s');
    monotone_ok_eval hd fuel s

val lemma_code_explicit_leakage_free: (ts:taintState) -> (code:tainted_code) -> (fuel:nat) -> (s1:traceState) -> (s2:traceState) -> Lemma
 (requires True)
 (ensures (let b, ts' = check_if_code_consumes_fixed_time code fuel ts in
  (b2t b ==> isConstantTimeGivenStates code fuel ts s1 s2 /\ isExplicitLeakageFreeGivenStates code fuel ts ts' s1 s2)))
 (decreases %[code; 0])

val lemma_block_explicit_leakage_free: (ts:taintState) -> (codes:tainted_codes) -> (fuel:nat) -> (s1:traceState) -> (s2:traceState) -> Lemma
 (requires True)
 (ensures (let b, ts' = check_if_block_consumes_fixed_time codes fuel ts in
  (b2t b ==> isConstantTimeGivenStates (Block codes) fuel ts s1 s2 /\ isExplicitLeakageFreeGivenStates (Block codes) fuel ts ts' s1 s2)))
 (decreases %[codes;1])

let rec lemma_code_explicit_leakage_free ts code fuel s1 s2 = match code with
  | Ins ins -> lemma_ins_leakage_free ts fuel ins
  | Block block -> lemma_block_explicit_leakage_free ts block fuel s1 s2
  | IfElse ifCond ifTrue ifFalse ->     
    let b_fin, ts_fin = check_if_code_consumes_fixed_time code fuel ts in
    let st1, b1 = taint_eval_ocmp s1 ifCond in
    let st1 = {st1 with trace=BranchPredicate(b1)::s1.trace} in
    let st2, b2 = taint_eval_ocmp s2 ifCond in
    let st2 = {st2 with trace=BranchPredicate(b2)::s2.trace} in
    assert (b2t b_fin ==> constTimeInvariant ts s1 s2 /\ st1.state.ok /\ st2.state.ok ==> constTimeInvariant ts st1 st2);
    monotone_ok_eval ifTrue fuel st1;
    monotone_ok_eval ifTrue fuel st2;
    lemma_code_explicit_leakage_free ts ifTrue fuel st1 st2;
    monotone_ok_eval ifFalse fuel st1;
    monotone_ok_eval ifFalse fuel st2;
    lemma_code_explicit_leakage_free ts ifFalse fuel st1 st2;
    ()
  | _ -> ()

and lemma_block_explicit_leakage_free ts block fuel s1 s2 = match block with
  | [] -> ()
  | hd :: tl ->
    let b, ts' = check_if_code_consumes_fixed_time hd fuel ts in
    lemma_code_explicit_leakage_free ts hd fuel s1 s2;
    let s'1 = taint_eval_code hd fuel s1 in
    let s'2 = taint_eval_code hd fuel s2 in
    if None? s'1 || None? s'2 then ()
    else
    let s'1 = Some?.v s'1 in
    let s'2 = Some?.v s'2 in
    lemma_block_explicit_leakage_free ts' tl fuel s'1 s'2;
    monotone_ok_eval (Block tl) fuel s'1;
    monotone_ok_eval (Block tl) fuel s'2

val lemma_code_leakage_free: (ts:taintState) -> (code:tainted_code) -> (fuel:nat) -> Lemma
 (let b, ts' = check_if_code_consumes_fixed_time code fuel ts in
  (b2t b ==> isConstantTime code fuel ts /\ isLeakageFree code fuel ts ts'))

let lemma_code_leakage_free ts code fuel = FStar.Classical.forall_intro_2 (lemma_code_explicit_leakage_free ts code fuel)
  
(* val check_if_code_is_leakage_free: (code:tainted_code) -> (ts:taintState) -> (tsExpected:taintState) -> (b:bool{b ==> isLeakageFree code ts tsExpected
	 /\ b ==> isConstantTime code ts})


let check_if_code_is_leakage_free code ts tsExpected = 
  let b, ts' = check_if_code_consumes_fixed_time code ts in

  if b then
    publicTaintsAreAsExpected ts' tsExpected
  else
    b

*)
