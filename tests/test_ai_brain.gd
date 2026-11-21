extends GutTest
## AIBrain finds its NavigationAgent3D, and only asks for a new path once the target has moved
## repath_distance metres.


## Lets the brain run at least one physics frame.
func physics_frames() -> void:
	for i in 2:
		await get_tree().physics_frame


func test_new_path_only_when_the_target_moves_enough() -> void:
	var body := CharacterBody3D.new()
	var agent := NavigationAgent3D.new()
	var brain := AIBrain.new()
	for node in [agent, ComponentManager.new(), brain]:
		body.add_child(node)
	var target := Node3D.new()
	target.position = Vector3(5, 0, 0)
	add_child_autofree(target)
	add_child_autofree(body)
	assert_eq(brain.agent, agent, "found without setting the Agent")
	brain.target = target
	await physics_frames()
	assert_eq(agent.target_position, Vector3(5, 0, 0))
	target.position = Vector3(5.5, 0, 0)
	await physics_frames()
	assert_eq(agent.target_position, Vector3(5, 0, 0), "moved less than repath_distance")
	target.position = Vector3(8, 0, 0)
	await physics_frames()
	assert_eq(agent.target_position, Vector3(8, 0, 0))
	assert_eq(brain.aim_point, Vector3(8, 1, 0), "aims at the chest, aim_height above the feet")
