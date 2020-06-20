port module Ports.Stripe exposing
    ( redirectToCheckout
    , redirectToCheckoutError
    )


port redirectToCheckout : String -> Cmd msg


port redirectToCheckoutError : (String -> msg) -> Sub msg
