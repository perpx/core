%lang starknet

func setup_helpers() {
    %{
        mod = PRIME

        def signed_int(value):
            return value if value <= mod/2 else -(mod - value)

        context.signed_int = signed_int
    %}
    return ();
}
