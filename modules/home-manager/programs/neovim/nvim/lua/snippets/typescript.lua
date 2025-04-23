return {
    s("gg", fmt("function* () {{\n\t{}\n}}", { i(0) })),
    s("egg", fmt("Effect.gen(function* () {{\n\t{}\n}})", { i(0) })),
    s("fegg", fmt("function {}({}) {{\n\treturn Effect.gen(function* () {{\n\t\t{}\n\t}});\n}}", { i(1), i(2), i(0) })),
    s("yy", fmt("yield* {};", { i(0) })),
    s("cyy", fmt("const {} = yield* {};", { i(1), i(0) })),
}
