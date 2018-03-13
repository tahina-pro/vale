module Low_Sem

module M = Memory
open Machine

type mem = M.heap

noeq type state = {
  ok:bool;
  regs : reg -> nat64;
  mem: mem;
}

let eval_reg (r:reg) (s:state) : nat64 = s.regs r

let eval_maddr (m:maddr) (s:state) : int =
  match m with
  | MConst n -> n
  | MReg r offset -> (eval_reg r s) + offset

val valid_mem: ptr:int -> h:mem -> bool
assume val load_mem: ptr:int -> h:mem -> nat64
assume val store_mem: ptr:int -> v:nat64 -> h:mem -> mem

let valid_mem ptr h = if ptr < 0 then false else not (M.addr_unused_in ptr h)