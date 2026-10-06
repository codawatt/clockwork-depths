class_name PrimitiveFactory
extends RefCounted

static func material(color: Color, emission_strength: float = 0.0, roughness: float = 0.72) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	if emission_strength > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission_strength
	return result

static func box_visual(size: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color, emission)
	return node

static func sphere_visual(radius: float, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.material_override = material(color, emission)
	return node

static func cylinder_visual(radius: float, height: float, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = material(color, emission)
	return node

static func capsule_visual(radius: float, height: float, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	node.mesh = mesh
	node.material_override = material(color, emission)
	return node

static func box_shape(size: Vector3) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	node.shape = shape
	return node

static func sphere_shape(radius: float) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	node.shape = shape
	return node

static func capsule_shape(radius: float, height: float) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	node.shape = shape
	return node
