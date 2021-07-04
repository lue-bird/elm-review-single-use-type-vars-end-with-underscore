module No.MultiUse.TypeVar.Has.Suffix_ exposing (rule)

{-|

@docs rule

-}

import Review.Rule as Rule exposing (Rule)


{-| Reports... REPLACEME

    config =
        [ No.MultiUse.TypeVar.Has.Suffix_.rule
        ]


## Fail

    a =
        "REPLACEME example to replace"


## Success

    a =
        "REPLACEME example to replace"


## When (not) to enable this rule

This rule is useful when REPLACEME.
This rule is not useful when REPLACEME.


## Try it out

You can try this rule out by running the following command:

```bash
elm-review --template lue-bird/elm-review-only-every-single-use-type-var-has-suffix-_/example --rules No.MultiUse.TypeVar.Has.Suffix_
```

-}
rule : Rule
rule =
    Rule.newModuleRuleSchema "No.MultiUse.TypeVar.Has.Suffix_" ()
        -- Add your visitors
        |> Rule.fromModuleRuleSchema