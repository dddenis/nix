return {
    s(
        "rc",
        fmt(
            [[
        export type {}Props = {{
          {}
        }};

        export const {} = (props: {}Props) => {{
          return <></>;
        }};
        ]],
            { i(1), i(0), rep(1), rep(1) }
        )
    ),
}
