import Verbose.Tactics.Common

open Lean

namespace Verbose.French

declare_syntax_cat maybeAppliedFR
syntax term : maybeAppliedFR
syntax term "appliqué à " term : maybeAppliedFR
syntax term "appliqué à [" term,* "]" : maybeAppliedFR
syntax term "appliqué à " term " en utilisant " term : maybeAppliedFR
syntax term "appliqué à " term " en utilisant que " term : maybeAppliedFR
syntax term "appliqué à " term " en utilisant [" term,* "]" : maybeAppliedFR

def maybeAppliedFRToTerm : TSyntax `maybeAppliedFR → MetaM Term
| `(maybeAppliedFR| $e:term) => pure e
| `(maybeAppliedFR| $e:term appliqué à $x:term) => `($e $x)
| `(maybeAppliedFR| $e:term appliqué à $x:term en utilisant $y) => `($e $x $y)
| `(maybeAppliedFR| $e:term appliqué à $x:term en utilisant que $y) => `($e $x (strongAssumption% $y))
| `(maybeAppliedFR| $e:term appliqué à $x:term en utilisant [$args:term,*]) => `($e $x $args*)
| `(maybeAppliedFR| $e:term appliqué à [$args:term,*]) => `($e $args*)
| _ => pure ⟨Syntax.missing⟩ -- This should never happen

declare_syntax_cat newStuffFR
syntax (ppSpace colGt maybeTypedIdent)* : newStuffFR
syntax maybeTypedIdent "tel que" (ppSpace colGt maybeTypedIdent)* : newStuffFR

def newStuffFRToArray : TSyntax `newStuffFR → Array MaybeTypedIdent
| `(newStuffFR| $news:maybeTypedIdent*) => Array.map toMaybeTypedIdent news
| `(newStuffFR| $x:maybeTypedIdent tel que $news:maybeTypedIdent*) =>
    #[toMaybeTypedIdent x] ++ (Array.map toMaybeTypedIdent news)
| _ => #[]

declare_syntax_cat newFactsFR
syntax colGt namedType : newFactsFR
syntax colGt namedType " et "  colGt namedType : newFactsFR
syntax colGt namedType ", "  colGt namedType " et "  colGt namedType : newFactsFR

def newFactsFRToArray : TSyntax `newFactsFR → Array NamedType
| `(newFactsFR| $x:namedType) => #[toNamedType x]
| `(newFactsFR| $x:namedType et $y:namedType) =>
    #[toNamedType x, toNamedType y]
| `(newFactsFR| $x:namedType, $y:namedType et $z:namedType) =>
    #[toNamedType x, toNamedType y, toNamedType z]
| _ => #[]

def newFactsFRToTypeTerm : TSyntax `newFactsFR → MetaM Term
| `(newFactsFR| $x:namedType) => do
    namedTypeToTypeTerm x
| `(newFactsFR| $x:namedType et $y) => do
    let xT ← namedTypeToTypeTerm x
    let yT ← namedTypeToTypeTerm y
    `($xT ∧ $yT)
| `(newFactsFR| $x:namedType, $y:namedType et $z) => do
    let xT ← namedTypeToTypeTerm x
    let yT ← namedTypeToTypeTerm y
    let zT ← namedTypeToTypeTerm z
    `($xT ∧ $yT ∧ $zT)
| _ => throwError "N'a pas pu convertir la description des nouveaux faits en un terme."

open Std Tactic Lean.Elab.Tactic.RCases in
def newFactsFRToRCasesPatt : TSyntax `newFactsFR → RCasesPatt
| `(newFactsFR| $x:namedType) => namedTypeListToRCasesPatt [x]
| `(newFactsFR| $x:namedType et $y:namedType) => namedTypeListToRCasesPatt [x, y]
| `(newFactsFR|  $x:namedType, $y:namedType et $z:namedType) => namedTypeListToRCasesPatt [x, y, z]
| _ => default

declare_syntax_cat newObjectFR
syntax maybeTypedIdent "tel que" maybeTypedIdent : newObjectFR
syntax maybeTypedIdent "tel que" maybeTypedIdent colGt " et " maybeTypedIdent : newObjectFR

def newObjectFRToTerm : TSyntax `newObjectFR → MetaM Term
| `(newObjectFR| $x:maybeTypedIdent tel que $new) => do
    let x' ← maybeTypedIdentToExplicitBinder x
    -- TODO Better error handling
    let newT := (toMaybeTypedIdent new).2.get!
    `(∃ $(.mk x'), $newT)
| `(newObjectFR| $x:maybeTypedIdent tel que $new₁ et $new₂) => do
    let x' ← maybeTypedIdentToExplicitBinder x
    let new₁T := (toMaybeTypedIdent new₁).2.get!
    let new₂T := (toMaybeTypedIdent new₂).2.get!
    `(∃ $(.mk x'), $new₁T ∧ $new₂T)
| _ => throwError "N'a pas pu convertir la description du nouvel object en un terme."

-- TODO: create helper functions for the values below
open Std Tactic Lean.Elab.Tactic.RCases in
def newObjectFRToRCasesPatt : TSyntax `newObjectFR → RCasesPatt
| `(newObjectFR| $x:maybeTypedIdent tel que $new) => maybeTypedIdentListToRCasesPatt [x, new]
| `(newObjectFR| $x:maybeTypedIdent tel que $new₁ et $new₂) => maybeTypedIdentListToRCasesPatt [x, new₁, new₂]
| _ => default

declare_syntax_cat factsFR
syntax term : factsFR
syntax term " et " term : factsFR
syntax term ", " term " et " term : factsFR

def factsFRToArray : TSyntax `factsFR → Array Term
| `(factsFR| $x:term) => #[x]
| `(factsFR| $x:term et $y:term) => #[x, y]
| `(factsFR| $x:term, $y:term et $z:term) => #[x, y, z]
| _ => #[]

def arrayToFactsFR : Array Term → CoreM (TSyntax `factsFR)
| #[x] => `(factsFR| $x:term)
| #[x, y] => `(factsFR| $x:term et $y:term)
| #[x, y, z] => `(factsFR| $x:term, $y:term et $z:term)
| _ => default


end Verbose.French

/-- Convert an expression to a `maybeAppliedFR` syntax object, in `MetaM`. -/
def Lean.Expr.toMaybeAppliedFR (e : Expr) : MetaM (TSyntax `maybeAppliedFR) := do
  let fn := e.getAppFn
  let fnS ← PrettyPrinter.delab fn
  match e.getAppArgs.toList with
  | [] => `(maybeAppliedFR|$fnS:term)
  | [x] => do
      let xS ← PrettyPrinter.delab x
      `(maybeAppliedFR|$fnS:term appliqué à $xS:term)
  | s => do
      let mut arr : Syntax.TSepArray `term "," := ∅
      for x in s do
        arr := arr.push (← PrettyPrinter.delab x)
      `(maybeAppliedFR|$fnS:term appliqué à [$arr:term,*])
