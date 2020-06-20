module QueryType exposing (QueryType(..), decode, encode)


type QueryType
    = Me
    | Project
    | Gripe
    | GripesWithCounts
    | CreateGripe
    | UpdateGripeTitle
    | CreateComment
    | CompleteGripe
    | DiscardGripe
    | RestoreGripe
    | OwnedProjects
    | CreateProject
    | ClaimProject
    | CreateCheckoutSession
    | IsProjectNameAvailable
    | ProjectPlan
    | Onboarding
    | FinishOnboarding


encode : QueryType -> String
encode queryType =
    case queryType of
        Me ->
            "Me"

        Project ->
            "Project"

        Gripe ->
            "Gripe"

        GripesWithCounts ->
            "GripesWithCounts"

        CreateGripe ->
            "CreateGripe"

        UpdateGripeTitle ->
            "UpdateGripeTitle"

        CreateComment ->
            "CreateComment"

        CompleteGripe ->
            "CompleteGripe"

        DiscardGripe ->
            "DiscardGripe"

        RestoreGripe ->
            "RestoreGripe"

        OwnedProjects ->
            "OwnedProjects"

        CreateProject ->
            "CreateProject"

        ClaimProject ->
            "ClaimProject"

        CreateCheckoutSession ->
            "CreateCheckoutSession"

        IsProjectNameAvailable ->
            "IsProjectNameAvailable"

        ProjectPlan ->
            "ProjectPlan"

        Onboarding ->
            "Onboarding"

        FinishOnboarding ->
            "FinishOnboarding"


decode : String -> Maybe QueryType
decode queryName =
    case queryName of
        "Me" ->
            Just Me

        "Project" ->
            Just Project

        "Gripe" ->
            Just Gripe

        "GripesWithCounts" ->
            Just GripesWithCounts

        "CreateGripe" ->
            Just CreateGripe

        "UpdateGripeTitle" ->
            Just UpdateGripeTitle

        "CreateComment" ->
            Just CreateComment

        "CompleteGripe" ->
            Just CompleteGripe

        "DiscardGripe" ->
            Just DiscardGripe

        "RestoreGripe" ->
            Just RestoreGripe

        "OwnedProjects" ->
            Just OwnedProjects

        "CreateProject" ->
            Just CreateProject

        "ClaimProject" ->
            Just ClaimProject

        "CreateCheckoutSession" ->
            Just CreateCheckoutSession

        "IsProjectNameAvailable" ->
            Just IsProjectNameAvailable

        "ProjectPlan" ->
            Just ProjectPlan

        "Onboarding" ->
            Just Onboarding

        "FinishOnboarding" ->
            Just FinishOnboarding

        _ ->
            Nothing
