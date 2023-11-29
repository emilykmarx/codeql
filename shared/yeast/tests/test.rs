#![cfg(test)]
use yeast::*;

#[test]
fn test_ruby_multiple_assignment() {
    // We want to convert this
    //
    // x, y, z = e
    //
    // into this
    //
    // __tmp_1 = e
    // x = __tmp_1[0]
    // y = __tmp_1[1]
    // z = __tmp_1[2]

    // Define a desugaring rule, which is a query together with a transformation.

    let query = Query::new();
    let transform = |captures| {
        // construct the new tree here maybe
        // captures is probably a HashMap from capture name to AST node
        Ast::example(tree_sitter_ruby::language())
    };
    let rule = Rule::new(query, transform);

    let input = "x, y, z = e";

    // Construct the thing that runs our desugaring process
    let runner = Runner::new(tree_sitter_ruby::language(), vec![rule]);

    // Run it on our example
    let output = runner.run(input);

    // we could create a macro for this
    // let expected_output = ast! {
    //     assignment {
    //         left: identifier { name: "__tmp" },
    //         right: identifier { name: "e" },
    //     },
    //     assignment {
    //         left: identifier { name: "x" },
    //         right: element_reference {
    //             object: identifier { name: "__tmp" },
    //             index: integer(0)
    //         },
    //     },
    //     assignment {
    //         left: identifier { name: "y" },
    //         right: element_reference {
    //             object: identifier { name: "__tmp" },
    //             index: integer(1)
    //         },
    //     },
    //     assignment {
    //         left: identifier { name: "z" },
    //         right: element_reference {
    //             object: identifier { name: "__tmp" },
    //             index: integer(2)
    //         },
    //     },
    // };
    let expected_output = todo!();

    assert_eq!(output, expected_output);
}
