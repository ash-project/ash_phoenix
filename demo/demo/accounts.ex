defmodule Demo.Accounts do
  use Ash.Api, otp_app: :ash_phoenix

  resources do
    registry Demo.Accounts.Registry
  end
end
