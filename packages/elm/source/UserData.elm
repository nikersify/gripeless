module UserData exposing (User(..), UserDiffed(..))

import Gegangen.Models


type User
    = LoggedIn Gegangen.Models.User
    | Anonymous String


type UserDiffed
    = Loaded User
    | Error String
    | Loading
