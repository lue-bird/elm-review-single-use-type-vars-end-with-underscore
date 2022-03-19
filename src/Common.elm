module Common exposing (collectTypeVarsFromDeclaration, groupBy, multiUseTypeVarsEndWith_ErrorInfo, singleUseTypeVarDoesntEndWith_ErrorInfo)

import Elm.Syntax.Declaration exposing (Declaration(..))
import Elm.Syntax.Expression exposing (Expression(..), LetDeclaration(..))
import Elm.Syntax.Node as Node exposing (Node(..))
import Elm.Syntax.TypeAnnotation exposing (TypeAnnotation(..))
import List.Extra as List


collectTypeVarsFromDeclaration :
    Declaration
    ->
        { inAnnotation : List (Node String)
        , inLets : List (Node String)
        }
collectTypeVarsFromDeclaration declaration =
    let
        noTypeVars =
            { inAnnotation = [], inLets = [] }
    in
    case declaration of
        FunctionDeclaration function ->
            { inAnnotation =
                case function.signature of
                    Nothing ->
                        []

                    Just (Node _ { typeAnnotation }) ->
                        typeAnnotation |> allTypeVarsInType
            , inLets =
                let
                    allTypeVarsInExpression expression =
                        List.concat
                            [ case expression of
                                LetExpression letBlock ->
                                    let
                                        typesInLetDeclaration :
                                            LetDeclaration
                                            -> Maybe (Node TypeAnnotation)
                                        typesInLetDeclaration letDeclaration =
                                            case letDeclaration of
                                                LetFunction { signature } ->
                                                    signature
                                                        |> Maybe.map (.typeAnnotation << Node.value)

                                                _ ->
                                                    Nothing
                                    in
                                    letBlock.declarations
                                        |> List.filterMap
                                            (typesInLetDeclaration << Node.value)
                                        |> List.concatMap allTypeVarsInType

                                _ ->
                                    []
                            , expression
                                |> subExpressions
                                |> List.map Node.value
                                |> List.concatMap allTypeVarsInExpression
                            ]
                in
                function.declaration
                    |> Node.value
                    |> .expression
                    |> Node.value
                    |> allTypeVarsInExpression
            }

        PortDeclaration { typeAnnotation } ->
            { inAnnotation = typeAnnotation |> allTypeVarsInType
            , inLets = []
            }

        CustomTypeDeclaration _ ->
            noTypeVars

        AliasDeclaration _ ->
            noTypeVars

        Destructuring _ _ ->
            noTypeVars

        InfixDeclaration _ ->
            noTypeVars


{-| Get all immediate child expressions of an expression.
-}
subExpressions : Expression -> List (Node Expression)
subExpressions expression =
    case expression of
        LetExpression letBlock ->
            letBlock.declarations
                |> List.map Node.value
                |> List.map
                    (\letDeclaration ->
                        case letDeclaration of
                            LetFunction { declaration } ->
                                declaration |> Node.value |> .expression

                            LetDestructuring _ expression_ ->
                                expression_
                    )
                |> (::) letBlock.expression

        ListExpr expressions ->
            expressions

        TupledExpression expressions ->
            expressions

        RecordExpr fields ->
            fields |> List.map (\(Node _ ( _, value )) -> value)

        RecordUpdateExpression record updaters ->
            (record |> Node.map (FunctionOrValue []))
                :: (updaters |> List.map (\(Node _ ( _, newValue )) -> newValue))

        Application expressions ->
            expressions

        CaseExpression caseBlock ->
            caseBlock.expression
                :: (caseBlock.cases |> List.map (\( _, expression_ ) -> expression_))

        OperatorApplication _ _ e1 e2 ->
            [ e1, e2 ]

        IfBlock predExpr thenExpr elseExpr ->
            [ predExpr, thenExpr, elseExpr ]

        LambdaExpression lambda ->
            [ lambda.expression ]

        RecordAccess record _ ->
            [ record ]

        ParenthesizedExpression expression_ ->
            [ expression_ ]

        Negation expression_ ->
            [ expression_ ]

        UnitExpr ->
            []

        Integer _ ->
            []

        Hex _ ->
            []

        Floatable _ ->
            []

        Literal _ ->
            []

        CharLiteral _ ->
            []

        GLSLExpression _ ->
            []

        RecordAccessFunction _ ->
            []

        FunctionOrValue _ _ ->
            []

        Operator _ ->
            []

        PrefixOperator _ ->
            []


allTypeVarsInType : Node TypeAnnotation -> List (Node String)
allTypeVarsInType type_ =
    case Node.value type_ of
        Unit ->
            []

        GenericType typeVarName ->
            [ Node (Node.range type_) typeVarName ]

        Typed _ typeArguments ->
            typeArguments
                |> List.concatMap allTypeVarsInType

        FunctionTypeAnnotation a b ->
            [ a, b ]
                |> List.concatMap allTypeVarsInType

        Tupled innerTypes ->
            innerTypes
                |> List.concatMap allTypeVarsInType

        Record fields ->
            fields
                |> List.map (\(Node _ ( _, type__ )) -> type__)
                |> List.concatMap allTypeVarsInType

        GenericRecord toExtend fields ->
            toExtend
                :: (fields
                        |> Node.value
                        |> List.map (\(Node _ ( _, type__ )) -> type__)
                        |> List.concatMap allTypeVarsInType
                   )



--


groupBy : (a -> comparable_) -> List a -> List ( a, List a )
groupBy toComparable list =
    list
        |> List.sortBy toComparable
        |> List.groupWhile
            (\a b -> toComparable a == toComparable b)



--


singleUseTypeVarDoesntEndWith_ErrorInfo :
    { typeVar : String, typeVar_Exists : Bool }
    -> { message : String, details : List String }
singleUseTypeVarDoesntEndWith_ErrorInfo { typeVar, typeVar_Exists } =
    { message =
        String.concat
            [ "The type variable `"
            , typeVar
            , "` isn't marked as single-use with a -_ suffix."
            ]
    , details =
        [ biggestReasonOfExistence
        , if typeVar_Exists then
            String.concat
                [ "Choose a different name (`"
                , typeVar
                , "_` already exists)."
                , " Then add the -_ suffix."
                ]

          else
            "Add the -_ suffix (there's a fix available for that)."
        ]
    }


multiUseTypeVarsEndWith_ErrorInfo :
    { typeVar : String, typeVarWithout_Exists : Bool }
    -> { message : String, details : List String }
multiUseTypeVarsEndWith_ErrorInfo { typeVar, typeVarWithout_Exists } =
    { message =
        String.concat
            [ "The type variable `"
            , typeVar
            , "` is used in multiple places,"
            , " despite being marked as single-use with the -_ suffix."
            ]
    , details =
        [ biggestReasonOfExistence
        , "Rename one of them if this was an accident. "
        , String.concat
            [ "If it wasn't an accident, "
            , if typeVarWithout_Exists then
                [ "choose a different name (`"
                , typeVar |> String.dropRight 1
                , "` already exists)."
                ]
                    |> String.concat

              else
                "remove the -_ suffix (there's a fix available for that)."
            ]
        ]
    }


biggestReasonOfExistence : String
biggestReasonOfExistence =
    "-_ at the end of a type variable is a good indication that it is used only in this one place."
