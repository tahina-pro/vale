// Turn high-level AST into low-level lemmas:
//   - call transform.fs
//   - then generate lemmas

module Emit_common_lemmas

open Ast
open Ast_util
open Parse
open Parse_util
open Transform
open Emit_common_base
open Microsoft.FSharp.Math
open System.Numerics

type build_env =
  {
    proc:proc_decl;
    loc:loc;
    is_instruction:bool;
    is_operand:bool;
    is_framed:bool;
    code_name:id;
    frame_exp:id -> exp;
    gen_fast_block:exp list -> stmt list -> stmt list;
    gen_fast_block_funs:unit -> decls;
  }

(* Build code value for body of procedure Q:
function method{:opaque} va_code_Q(...):va_code
{
  va_Block(va_CCons(va_code_P(va_op_reg(EBX), 10), va_CCons(va_code_P(va_op_reg(EBX), 20), va_CCons(va_code_P(va_op_reg(EBX), 30), va_CNil()))))
}
*)
let rec build_code_stmt (env:env) (s:stmt):exp list =
  let rec assign e =
    match e with
    | ELoc (_, e) -> assign e
    | EApply (Id x, es) when Map.containsKey (Id x) env.procs ->
        let es = List.filter (fun e -> match e with EOp (Uop UGhostOnly, _) -> false | _ -> true) es in
        let es = List.map get_code_exp es in
        let es = List.map (map_exp stateToOp) es in
        [vaApp ("code_" + x) es]
    | _ -> []
    in
  match s with
  | SLoc (loc, s) ->
      try List.map (fun e -> ELoc (loc, e)) (build_code_stmt env s) with err -> raise (LocErr (loc, err))
  | SBlock b -> [build_code_block env b]
  | SFastBlock b -> [build_code_block env b]
  | SIfElse (SmPlain, cmp, ss1, ss2) ->
      let e1 = build_code_block env ss1 in
      let e2 = build_code_block env ss2 in
      [vaApp "IfElse" [map_exp stateToOp cmp; e1; e2]]
  | SIfElse (SmInline, cmp, ss1, ss2) ->
      let e1 = build_code_block env ss1 in
      let e2 = build_code_block env ss2 in
      [EOp (Cond, [map_exp stateToOp cmp; e1; e2])]
  | SWhile (cmp, ed, invs, ss) ->
      let ess = build_code_block env ss in
      [vaApp "While" [map_exp stateToOp cmp; ess]]
  | SAssign (_, e) -> assign e
  | _ -> []
and build_code_block (env:env) (stmts:stmt list):exp =
  let empty = vaApp "CNil" [] in
  let cons el e = vaApp "CCons" [e; el] in
  let slist = List.collect (build_code_stmt env) stmts in
  let elist = List.fold cons empty (List.rev slist) in
  vaApp "Block" [elist]

// compute function parameters
// pfIsRet == false ==> pf is input parameter
// pfIsRet == true ==> pf is output return value
let make_fun_param (modifies:bool) (pfIsRet:bool) (pf:pformal):formal list =
  let (x, t, storage, io, attrs) = pf in
  let fx = (x, Some t) in
  match (storage, pfIsRet, modifies) with
  | (XInline, false, false) -> [fx]
  | ((XGhost | XAlias _), _, false) -> []
  | (XOperand xo, _, false) -> [(x, Some (tOperand xo))]
  | (_, _, true) -> []
  | (XInline, true, _) -> internalErr "XInline"
  | (XState _, _, _) -> internalErr "XState"
  | (XPhysical, _, _) -> internalErr "XPhysical"

let make_fun_params (prets:pformal list) (pargs:pformal list):formal list =
  (List.collect (make_fun_param false true) prets) @
  (List.collect (make_fun_param true true) prets) @
  (List.collect (make_fun_param false false) pargs) @
  (List.collect (make_fun_param true false) pargs)

// compute parameters/returns for procedures (abstract/concrete/lemma) 
// pfIsRet == false ==> pf is input parameter
// pfIsRet == true ==> pf is output return value
// ret == false ==> generate parameters
// ret == true ==> generate return values
let make_proc_param (modifies:bool) (pfIsRet:bool) (ret:bool) (pf:pformal):pformal list =
  let (x, t, storage, io, attrs) = pf in
  let pfOp xo = (x, tOperand xo, XPhysical, In, attrs) in
  match (ret, storage, pfIsRet, modifies) with
  | (_, XGhost, _, false) -> if ret = pfIsRet then [pf] else []
  | (_, _, _, true) -> []
  | (false, XInline, false, false) -> [pf]
  | (_, XOperand xo, _, false) -> if ret = pfIsRet then [pfOp xo] else []
  | (_, XAlias _, _, false) -> []
  | (true, XInline, false, _) -> []
  | (_, XInline, true, _) -> internalErr "XInline"
  | (_, XState _, _, _) -> internalErr "XState"
  | (_, XPhysical, _, _) -> internalErr "XPhysical"

let make_proc_params (ret:bool) (prets:pformal list) (pargs:pformal list):pformal list =
  (List.collect (make_proc_param false true ret) prets) @
  (List.collect (make_proc_param true true ret) prets) @
  (List.collect (make_proc_param false false ret) pargs) @
  (List.collect (make_proc_param true false ret) pargs)

let specModIo (env:env) (loc:loc, s:spec):(inout * (id * typ)) list =
  match s with
  | Requires _ | Ensures _ -> []
  | Modifies (readWrite, e) ->
    (
      let io = if readWrite then InOut else In in
      match skip_loc (exp_abstract false e) with
      | EVar x ->
        (
          match Map.tryFind x env.ids with
          | Some (StateInfo (_, _, t)) -> [(io, (x, t))]
          | _ -> internalErr ("specMod: could not find variable " + (err_id x))
        )
      | _ -> []
    )
  | SpecRaw _ -> internalErr "SpecRaw"

let lemma_block (sM:lhs) (cM:lhs) (bM:lhs) (eb:exp) (es0:exp) (esN:exp):stmt list =
  let eBlock = vaApp "lemma_block" [eb; es0; esN] in
  [SAssign ([sM; cM; bM], eBlock)] // ghost var va_ltmp1, va_cM:va_code, va_ltmp2 := va_lemma_block(va_b0, va_s0, va_sN);

let rec build_lemma_stmt (env:env) (benv:build_env) (block:id) (b1:id) (code:id) (src:id) (res:id) (resIn:id) (loc:loc) (s:stmt):ghost * bool * stmt list =
  let sub es e = subst_reserved_exp (Map.ofList [(Reserved "s", es)]) e in
  let sub_src e = sub (EVar src) e in
  let rec assign lhss e =
    let lhss = List.map (fun xd -> match xd with (Reserved "s", None) -> (src, None) | _ -> xd) lhss in
    match e with
    | ELoc (loc, e) -> try assign lhss e with err -> raise (LocErr (loc, err))
    | EApply (x, es) when Map.containsKey x env.procs ->
        let p = Map.find x env.procs in
        let pargs = List.filter (fun (_, _, storage, _, _) -> match storage with XAlias _ -> false | _ -> true) p.pargs in
        let (pretsOp, pretsNonOp) = List.partition (fun (_, _, storage, _, _) -> match storage with XOperand _ -> true | _ -> false) p.prets in
        let pretsArgs = pretsOp @ pargs in
        let es = List.map (fun e -> match e with EOp (Uop UGhostOnly, [e]) -> sub_src e | _ -> e) es in
        let es = List.map (fun e -> match e with EOp (CodeLemmaOp, [_; e]) -> sub_src e | _ -> e) es in
        let es = List.map (map_exp stateToOp) es in
        let lemmaPrefix = "lemma_" in
        let lem = vaApp (lemmaPrefix + (string_of_id x)) ([EVar block; EVar src; EVar resIn] @ es) in
        let blockLhss = List.map varLhsOfId [b1; res] in
        (NotGhost, false, [SAssign (blockLhss @ lhss, lem)])
    | _ -> (Ghost, false, [SAssign (lhss, sub_src e)])
    in
  match s with
  | SLoc (loc, s) ->
      try
        let (g, b, ss) = build_lemma_stmt env benv block b1 code src res resIn loc s in
        (g, b, List.map (fun s -> SLoc (loc, s)) ss)
      with err -> raise (LocErr (loc, err))
  | SLabel _ -> err "unsupported feature: labels (unstructured code)"
  | SGoto _ -> err "unsupported feature: 'goto' (unstructured code)"
  | SReturn _ -> err "unsupported feature: 'return' (unstructured code)"
  | SAssume e -> (Ghost, false, [SAssume (sub_src e)])
  | SAssert (attrs, e) -> (Ghost, false, [SAssert (attrs, sub_src e)])
  | SCalc (oop, contents) ->
      let ccs = List.map (build_lemma_calcContents env benv src res loc sub_src) contents in
      (Ghost, false, [SCalc (oop, ccs)])
  | SVar (_, _, _, (XPhysical | XOperand _ | XInline | XAlias _), _, _) -> (Ghost, false, [])
  | SVar (x, t, m, g, a, eOpt) -> (Ghost, false, [SVar (x, t, m, g, a, mapOpt sub_src eOpt)])
  | SAlias _ -> (Ghost, false, [])
  | SLetUpdates _ -> internalErr "SLetUpdates"
  | SBlock b -> (NotGhost, true, build_lemma_block env benv (EVar code) src res loc b)
  | SFastBlock b ->
      let ss = benv.gen_fast_block [EVar src; EVar res] b in
      (NotGhost, true, ss)
  | SIfElse (SmGhost, e, ss1, ss2) ->
      let e = sub_src e in
      let ss1 = build_lemma_ghost_stmts env benv src res loc ss1 in
      let ss2 = build_lemma_ghost_stmts env benv src res loc ss2 in
      (Ghost, false, [SIfElse (SmGhost, e, ss1, ss2)])
  | SIfElse (SmPlain, e, ss1, ss2) ->
      let cond = Reserved ("cond_" + (reserved_id code)) in
      let i1 = string (gen_lemma_sym ()) in
      let s1 = Reserved("s" + i1) in
      let codeCond = vaApp "get_ifCond" [EVar code] in
      let codet = vaApp "get_ifTrue" [EVar code] in
      let codef = vaApp "get_ifFalse" [EVar code] in
      let lem = vaApp "lemma_ifElse" [codeCond; codet; codef; EVar src; EVar res] in
      let s1Lhs = (s1, Some (Some tState, Ghost)) in
      let sb1 = SAssign ([varLhsOfId cond; s1Lhs], lem) in
      let sbT = build_lemma_block env benv codet s1 res loc ss1 in
      let sbF = build_lemma_block env benv codef s1 res loc ss2 in
      (NotGhost, true, [sb1; SIfElse (SmPlain, EVar cond, sbT, sbF)])
  | SIfElse (SmInline, e, ss1, ss2) ->
      let sbT = build_lemma_block env benv (EVar code) src res loc ss1 in
      let sbF = build_lemma_block env benv (EVar code) src res loc ss2 in
      (NotGhost, true, [SIfElse (SmPlain, e, sbT, sbF)])
  | SWhile (e, invs, ed, ss) ->
      let codeCond = vaApp "get_whileCond" [EVar code] in
      let codeBody = vaApp "get_whileBody" [EVar code] in
      let i1 = string (gen_lemma_sym ()) in
      let i2 = string (gen_lemma_sym ()) in
      let (n1, s1, r1) = (Reserved ("n" + i1), Reserved ("s" + i1), Reserved ("sW" + i1)) in
      let r2 = (Reserved ("sW" + i2)) in
      let (codeCond, codeBody, sCodeVars) =
        if !fstar then
          // REVIEW: workaround for F* issue
          let (xc, xb) = (Reserved ("sC" + i1), Reserved ("sB" + i1)) in
          let sCond = SAssign ([(xc, None)], codeCond) in
          let sBody = SAssign ([(xb, None)], codeBody) in
          (EVar xc, EVar xb, [sCond; sBody])
        else (codeCond, codeBody, [])
        in
      let lem = vaApp "lemma_while" [codeCond; codeBody; EVar src; EVar res] in
      let lemTrue = vaApp "lemma_whileTrue" [codeCond; codeBody; EVar n1; EVar r1; EVar res] in
      let lemFalse = vaApp "lemma_whileFalse" [codeCond; codeBody; EVar r1; EVar res] in
      let n1Lhs = (n1, Some (Some tInt, Ghost)) in
      let s1Lhs = (s1, Some (Some tState, Ghost)) in
      let r1Lhs = (r1, Some (Some tState, Ghost)) in
      let r2Lhs = (r2, Some (Some tState, Ghost)) in
      let slem = SAssign ([n1Lhs; r1Lhs], lem) in
      let slemTrue = SAssign ([s1Lhs; r2Lhs], lemTrue) in
      let slemFalse = SAssign ([(res, None)], lemFalse) in
      let whileInv = vaApp "whileInv" [codeCond; codeBody; EVar n1; EVar r1; EVar res] in
      let r1Update = SAssign ([(r1, None)], EVar r2) in
      let n1Update = SAssign ([(n1, None)], EOp (Bop BSub, [EVar n1; EInt bigint.One])) in
      let sbBody = build_lemma_block env benv codeBody s1 r2 loc ss in
      let nCond = EOp (Bop BGt, [EVar n1; EInt bigint.Zero]) in
      let invFrame = (loc, benv.frame_exp r1) in
      let invFrames = if benv.is_framed then [invFrame] else [] in
      let invs = List_mapSnd (sub (EVar r1)) invs in
      let ed =
        match ed with
        | (loc, []) -> (loc, [EVar n1])
        | (loc, es) -> (loc, List.map (sub (EVar r1)) es)
        in
      let whileBody = slemTrue::sbBody @ [r1Update; n1Update] in
      let sWhile = SWhile (nCond, (loc, whileInv)::invs @ invFrames, ed, whileBody) in
      (NotGhost, true, sCodeVars @ [slem; sWhile; slemFalse])
  | SAssign (lhss, e) -> assign lhss e
  | SForall (xs, ts, ex, e, ss) ->
      let ts = List.map (List.map sub_src) ts in
      let ex = sub_src ex in
      let e = sub_src e in
      let ss = build_lemma_ghost_stmts env benv src res loc ss in
      (Ghost, false, [SForall (xs, ts, ex, e, ss)])
  | SExists (xs, ts, e) ->
      let ts = List.map (List.map sub_src) ts in
      let e = sub_src e in
      (Ghost, false, [SExists (xs, ts, e)])
and build_lemma_ghost_stmt (env:env) (benv:build_env) (src:id) (res:id) (loc:loc) (s:stmt):stmt list =
  let dummyId = Reserved "dummy" in
  let (g, _, ss) = build_lemma_stmt env benv dummyId dummyId dummyId src res res loc s in
  (match g with Ghost -> () | NotGhost -> err "Only ghost statements allowed here.  Ghost statements include 'forall', 'ghost if', lemma calls, assignments to ghost variables, assertions, etc, but not 'while' or 'if' or procedure calls.");
  ss
and build_lemma_ghost_stmts (env:env) (benv:build_env) (src:id) (res:id) (loc:loc) (stmts:stmt list):stmt list =
  List.collect (build_lemma_ghost_stmt env benv src res loc) stmts
and build_lemma_calcContents (env:env) (benv:build_env) (src:id) (res:id) (loc:loc) (sub_src:exp -> exp) (cc:calcContents):calcContents =
  let {calc_exp = e; calc_op = oop; calc_hints = hints} = cc in
  {calc_exp = sub_src e; calc_op = oop; calc_hints = List.map (build_lemma_ghost_stmts env benv src res loc) hints}
and build_lemma_stmts (env:env) (benv:build_env) (block:id) (src:id) (res:id) (loc:loc) (stmts:stmt list):stmt list =
  match stmts with
  | [] ->
      let lem = vaApp "lemma_empty" [EVar src; EVar res] in
      [SAssign ([(res, None)], lem)]
  | hd::tl ->
    (
      let i1 = string (gen_lemma_sym ()) in
      let (r1, c1, b1) = (Reserved ("s" + i1), Reserved ("c" + i1), Reserved ("b" + i1)) in
      let (ghost, addBlockLemma, sb2) = build_lemma_stmt env benv block b1 c1 src r1 res loc hd in
      match (ghost, addBlockLemma) with
      | (Ghost, _) ->
          let sb3 = build_lemma_stmts env benv block src res loc tl in
          sb2 @ sb3
      | (NotGhost, true) ->
          let sLoc = one_loc_of_stmt loc hd in
          let sb1 = lemma_block (varLhsOfId r1) (varLhsOfId c1) (varLhsOfId b1) (EVar block) (EVar src) (EVar res) in
          let sb3 = build_lemma_stmts env benv b1 r1 res loc tl in
          sb1 @ sb2 @ sb3
      | (NotGhost, false) ->
          let sb3 = build_lemma_stmts env benv b1 r1 res loc tl in
          sb2 @ sb3
    )
and build_lemma_block (env:env) (benv:build_env) (code:exp) (src:id) (res:id) (loc:loc) (stmts:stmt list):stmt list =
  let i0 = string (gen_lemma_sym ()) in
  let b0 = Reserved ("b" + i0) in
  let codeCond = vaApp "get_block" [code] in
  let sb1 = SAssign (List.map varLhsOfId [b0], codeCond) in
  let sb2 = build_lemma_stmts env benv b0 src res loc stmts in
  sb1::sb2

let build_lemma_spec (env:env) (src:id) (res:exp) (loc:loc, s:spec):((loc * spec) list * exp list) =
  try
    match s with
    | Requires (r, e) ->
        let e = exp_refined e in
        let m = Map.ofList [(Reserved "old_s", EVar src); (Reserved "s", EVar src)] in
        ([(loc, Requires (r, subst_reserved_exp m e))], [])
    | Ensures (r, e) ->
        let e = exp_refined e in
        let m = Map.ofList [(Reserved "old_s", EVar src); (Reserved "s", res)] in
        ([(loc, Ensures (r, subst_reserved_exp m e))], [])
    | Modifies (readWrite, e) ->
        let e = exp_refined e in
        let m = Map.ofList [(Reserved "old_s", EVar src); (Reserved "s", EVar src)] in
        ([], [subst_reserved_exp m e])
    | SpecRaw _ -> internalErr "SpecRaw"
  with err -> raise (LocErr (loc, err))

let fArg (x, t, g, io, a):exp list =
  match g with
  | XInline -> [EVar x]
  | XOperand _ -> [EVar x]
//  | XOperand _ -> [vaApp "op" [EVar x]]
  | _ -> []
  in

let make_gen_fast_block (loc:loc) (p:proc_decl):((exp list -> stmt list -> stmt list) * (unit -> decls)) =
  let next_sym = ref 0 in
  let funs = ref ([]:decls) in
  let fArgs = (List.collect fArg p.prets) @ (List.collect fArg p.pargs) in
  let fParams = make_fun_params p.prets p.pargs in
  let fIns (s:stmt):exp =
    let err () = internalErr "make_gen_fast_block" in
    match skip_loc_stmt s with
    | SAssign ([], e) ->
      (
        match skip_loc e with
        | EApply(Id x, es) ->
            let es = List.filter (fun e -> match e with EOp (Uop UGhostOnly, _) -> false | _ -> true) es in
            let es = List.map get_code_exp es in
            let es = List.map (map_exp stateToOp) es in
            let es = List.map exp_refined es in
            vaApp ("fast_ins_" + x) es
        | _ -> err ()
      )
    | _ -> err ()
    in
  let gen_fast_block args ss =
    incr next_sym;
    let id = Reserved ("ins_" + (string !next_sym) + "_" + (string_of_id p.pname)) in
    let inss = List.map fIns ss in
    let fBody = EApply (Id "list", inss) in
    let fCode =
      {
        fname = id;
        fghost = Ghost;
        fargs = fParams;
        fret = TName (Reserved "inss");
        fbody = Some fBody;
        fattrs = [];
      }
      in
    let dFun = DFun fCode in
    funs := (loc, dFun)::!funs;
    let eIns = EApply (id, fArgs) in
    let sLemma = SAssign ([], EApply (Reserved "lemma_weakest_pre_norm", eIns::args)) in
    [sLemma]
    in
  let gen_fast_block_funs () = List.rev !funs in
  (gen_fast_block, gen_fast_block_funs)

// Generate framing postcondition, which limits the variables that may be modified:
//   ensures  va_state_eq(va_sM, va_update_reg(EBX, va_sM, va_update_reg(EAX, va_sM, va_update_ok(va_sM, va_update(dummy2, va_sM, va_update(dummy, va_sM, va_s0))))))
let makeFrame (env:env) (p:proc_decl) (s0:id) (sM:id) =
  let specModsIo = List.collect (specModIo env) p.pspecs in
  let frameArg (isRet:bool) e (x, _, storage, io, _) =
    match (isRet, storage, io) with
    | (true, XOperand xo, _) | (_, XOperand xo, (InOut | Out)) -> vaApp ("update_" + xo) [EVar x; EVar sM; e]
    | _ -> e
    in
  let frameMod e (io, (x, _)) =
    match io with
    | (InOut | Out) ->
      (
        match Map.tryFind x env.ids with
        | Some (StateInfo (prefix, es, t)) -> vaApp ("update_" + prefix) (es @ [EVar sM; e])
        | _ -> internalErr ("frameMod: could not find variable " + (err_id x))
      )
    | _ -> e
    in
  let e = EVar s0 in
  let e = List.fold (frameArg true) e p.prets in
  let e = List.fold (frameArg false) e p.pargs in
  let e = List.fold frameMod e specModsIo in
  vaApp "state_eq" [EVar sM; e]

(* Build function for code for procedure Q
function method{:opaque} va_code_Q(iii:int, dummy:va_operand, dummy2:va_operand):va_code
{
  va_Block(...)
}
*)
let build_code (env:env) (benv:build_env) (stmts:stmt list):fun_decl =
  let p = benv.proc in
  let fParams = make_fun_params p.prets p.pargs in
  {
    fname = benv.code_name;
    fghost = NotGhost;
    fargs = fParams;
    fret = tCode;
    fbody =
      if benv.is_instruction then Some (attrs_get_exp (Id "instruction") p.pattrs)
      else Some (build_code_block env stmts);
    fattrs = [(Id "opaque", [])];
  }

let build_lemma (env:env) (benv:build_env) (b1:id) (stmts:stmt list) (bstmts:stmt list):proc_decl =
  // generate va_lemma_Q
  let p = benv.proc in
  let loc = benv.loc in
  let codeName = benv.code_name in
  let fArgs = (List.collect fArg p.prets) @ (List.collect fArg p.pargs) in

  (* Generate lemma prologue and boilerplate requires/ensures
      requires va_require(va_b0, va_code_Q(iii, va_op(dummy), va_op(dummy2)), va_s0, va_sN)
      ensures  va_ensure(va_b0, va_bM, va_s0, va_sM, va_sN)
    ...
    reveal_va_code_Q();
    var va_old_s:va_state := va_s0;
    ghost var va_ltmp1, va_cM:va_code, va_ltmp2 := va_lemma_block(va_b0, va_s0, va_sN);
    va_sM := va_ltmp1;
    va_bM := va_ltmp2;
    var va_b1:va_codes := va_get_block(va_cM);
  *)
  let (b0, s0, bM, sM, cM, sN) = (Reserved "b0", Reserved "s0", Reserved "bM", Reserved "sM", Reserved "cM", Reserved "sN") in
  let argB = (b0, tCodes, XPhysical, In, []) in
  let retB = (bM, tCodes, XPhysical, In, []) in
  let retR = (sM, tState, XPhysical, In, []) in
  let argS = (s0, tState, XPhysical, In, []) in
  let argR = (sN, tState, XPhysical, In, []) in
  let prets = make_proc_params true p.prets p.pargs in
  let pargs = make_proc_params false p.prets p.pargs in
  let pargs = [argS; argR] @ pargs in
  let req = require (vaApp "require" [EVar b0; EApply (codeName, fArgs); EVar s0; EVar sN]) in // va_require(va_b0, va_code_Q(iii, va_op(dummy), va_op(dummy2)), va_s0, va_sN)
  let ens = ensure (vaApp "ensure" ([EVar b0; EVar bM] @ [EVar s0; EVar sM; EVar sN])) in // va_ensure(va_b0, va_bM, va_s0, va_sM, va_sN)
  let lCM  = (cM, Some (Some tCode, NotGhost)) in
  let sBlock = lemma_block (sM, None) lCM (bM, None) (EVar b0) (EVar s0) (EVar sN) in // ghost var va_ltmp1, va_cM:va_code, va_ltmp2 := va_lemma_block(va_b0, va_s0, va_sN);
  let eReveal = if !precise_opaque then EApply (codeName, fArgs) else EVar codeName in
  let sReveal = SAssign ([], EOp (Uop UReveal, [eReveal])) in // reveal_va_code_Q();
  let sOldS = SVar (Reserved "old_s", Some tState, Immutable, XPhysical, [], Some (EVar s0)) in
  let eb1 = vaApp "get_block" [EVar cM] in
  let sb1 = SVar (b1, Some tCodes, Immutable, XPhysical, [], Some eb1) in // var va_b1:va_codes := va_get_block(va_cM);

  // Generate well-formedness for operands:
  //   requires va_is_dst_int(dummy, s0)
  let reqIsArg (isRet:bool) (x, t, storage, io, _) =
    match (isRet, storage, io) with
    | (true, XOperand xo, _) | (false, XOperand xo, (InOut | Out)) -> [vaAppOp ("is_dst_" + xo + "_") t [EVar x; EVar s0]]
    | (false, XOperand xo, In) -> [vaAppOp ("is_src_" + xo + "_") t [EVar x; EVar s0]]
    | _ -> []
    in
  let reqIsExps =
    (List.collect (reqIsArg true) p.prets) @
    (List.collect (reqIsArg false) p.pargs)
    in
  let reqsIs = List.map (fun e -> (loc, require e)) reqIsExps in

  let specModsIo = List.collect (specModIo env) p.pspecs in
  let eFrame = benv.frame_exp sM in

  (* Generate lemma for procedure p:
    lemma va_lemma_p(va_b0:va_codes, va_s0:va_state, va_sN:va_state)
      returns (va_bM:va_codes, va_sM:va_state)
      requires va_require(va_b0, va_code_p(), va_s0, va_sN)
      ensures  va_ensure(va_b0, va_bM, va_s0, va_sM, va_sN)
      requires ...
      ensures  ...
    {
      reveal_va_code_p();
      var va_old_s:va_state := va_s0;
      va_sM, (var va_cM:va_code), va_bM := va_lemma_block(va_b0, va_s0, va_sN);
      var va_b1:va_codes := va_get_block(va_cM);
      // this = va_s0
      ...
      va_sM := va_lemma_empty(va_s99, va_sM);
    }
  *)
  let pargs = argB::pargs in
  let prets = retB::retR::prets in
  let reqs = if benv.is_framed then reqsIs else [] in
  let sStmts =
    if benv.is_instruction then
      // Body of instruction lemma
      let ss = build_lemma_ghost_stmts env benv sM sM loc stmts in
      [sReveal; sOldS] @ sBlock @ ss
    else if benv.is_operand then
      err "operand procedures must be declared extern"
    else
      // Body of ordinary lemma
      let ss = stmts_refined bstmts in
      [sReveal; sOldS] @ sBlock @ [sb1] @ ss
    in
  let ensFrame = if benv.is_framed then [(loc, ensure eFrame)] else [] in
  let (pspecs, pmods) = List.unzip (List.map (build_lemma_spec env s0 (EVar sM)) p.pspecs) in
  {
    pname = Reserved ("lemma_" + (string_of_id p.pname));
    pghost = Ghost;
    pinline = Outline;
    pargs = pargs;
    prets = prets;
    pspecs = (loc, req)::reqs @ (loc, ens)::(List.concat pspecs) @ ensFrame;
    pbody = Some (sStmts);
    pattrs = List.filter filter_proc_attr p.pattrs;
  }

let build_proc (env:env) (loc:loc) (p:proc_decl):decls =
  gen_lemma_sym_count := 0;
  let isInstruction = List_mem_assoc (Id "instruction") p.pattrs in
  let isOperand = List_mem_assoc (Id "operand") p.pattrs in
  let codeName = Reserved ("code_" + (string_of_id p.pname)) in
  let reqs =
    List.collect (fun (loc, s) ->
        match s with
        | Requires (_, e) -> [ELoc (loc, e)]
        | _ -> []
      ) p.pspecs in
  let enss =
    List.collect (fun (loc, s) ->
        match s with
        | Ensures (_, e) -> [ELoc (loc, e)]
        | _ -> []
      ) p.pspecs in
  let bodyDecls =
    match p.pbody with
    | None -> []
    | Some stmts ->
        let s0 = Reserved "s0" in
        let i1 = string (gen_lemma_sym ()) in
        let b1 = Reserved ("b" + i1) in
        let fGhost s xss =
          match s with
          | SVar (x, _, _, XGhost, _, _) -> x::(List.concat xss)
          | _ -> List.concat xss
          in
        let (gen_fast_block, gen_fast_block_funs) = make_gen_fast_block loc p in
        let benv =
          {
            proc = p;
            loc = loc;
            is_instruction = isInstruction;
            is_operand = isOperand;
            is_framed = attrs_get_bool (Id "frame") true p.pattrs;
            code_name = codeName;
            frame_exp = makeFrame env p s0;
            gen_fast_block = gen_fast_block;
            gen_fast_block_funs = gen_fast_block_funs;
          }
          in
        let rstmts = stmts_refined stmts in
        let fCode = build_code env benv rstmts in
        let bstmts = build_lemma_stmts env benv b1 (Reserved "s0") (Reserved "sM") loc stmts in
        let pLemma = build_lemma env benv b1 rstmts bstmts in
        [(loc, DFun fCode)] @ (gen_fast_block_funs ()) @ [(loc, DProc pLemma)]
    in
  bodyDecls //@ blockLemmaDecls
