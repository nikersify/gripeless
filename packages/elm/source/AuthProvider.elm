module AuthProvider exposing (AuthProvider(..), toString)


type AuthProvider
    = Google
    | GitHub


toString : AuthProvider -> String
toString provider =
    case provider of
        Google ->
            "Google"

        GitHub ->
            "GitHub"
