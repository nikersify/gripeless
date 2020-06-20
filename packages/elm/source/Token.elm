module Token exposing (Token, TokenData, empty, unwrap, wrap)


type alias TokenData =
    Maybe String


type Token
    = Token (Maybe String)


wrap : TokenData -> Token
wrap maybeToken =
    Token maybeToken


unwrap : Token -> TokenData
unwrap (Token token) =
    token


empty : Token
empty =
    wrap Nothing
