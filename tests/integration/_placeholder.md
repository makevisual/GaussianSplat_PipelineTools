# integration tests

Scenario-named end-to-end tests. Each scenario gets a subdir like
`integration/image_to_render/` with a README describing inputs, steps,
and expected outputs.

The first planned scenario is `image_to_render/`: image sequence into
Apple Sharp, `.ply` sequence out, loaded onto VRay Gaussian Geometry in
3dsMax, rendered, diffed against a golden output.
