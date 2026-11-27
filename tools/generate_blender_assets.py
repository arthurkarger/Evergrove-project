"""Generate original, low-poly Evergrove props using Blender's Python API."""
import bpy
import math
import random
import json
import struct
from pathlib import Path
from mathutils import Vector

OUT = Path("blender-output")
OUT.mkdir(exist_ok=True)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, rgb, seed):
    rng = random.Random(seed)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.95
    img = bpy.data.images.new(name + "_pixels", width=16, height=16, alpha=False)
    pixels = []
    for y in range(16):
        for x in range(16):
            shade = 0.92 + 0.15*rng.random()
            if name in ("Wood", "Roof") and y % 4 == 0:
                shade *= 0.78
            pixels.extend([min(1, c*shade) for c in rgb] + [1])
    img.pixels = pixels
    img.pack()
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat

def paint(obj, mat, name):
    obj.name = name
    obj.data.materials.append(mat)
    return obj

def box(name, loc, size, mat, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return paint(obj, mat, name)

def cone(name, loc, r1, r2, depth, mat, vertices=7):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=loc)
    return paint(bpy.context.object, mat, name)

def rock(name, loc, size, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=loc)
    obj = bpy.context.object
    obj.scale = size
    return paint(obj, mat, name)

def house():
    wall=material("Plaster", (.81,.66,.43), 1)
    wood=material("Wood", (.29,.15,.075), 2)
    roof=material("Roof", (.48,.16,.12), 3)
    glass=material("Glass", (.24,.54,.58), 4)
    stone=material("Stone", (.46,.43,.38), 5)
    box("Foundation", (0,0,.13), (3.2,2.5,.26), stone)
    box("Walls", (0,0,1.13), (3,2.3,1.8), wall)
    # Roof slopes descend toward the front and back.
    for side in (-1,1):
        box("Roof slope", (0,side*.67,2.38), (3.45,1.69,.14), roof, (math.radians(-side*37),0,0))
    # Fill both triangular gables beneath the roof.
    for x in (-1.49,1.49):
        verts=[(x,-1.14,2.02),(x,1.14,2.02),(x,0,2.87)]
        mesh=bpy.data.meshes.new("Gable")
        mesh.from_pydata(verts,[],[(0,1,2) if x>0 else (2,1,0)])
        mesh.update()
        uv=mesh.uv_layers.new()
        for i,loop in enumerate(mesh.loops):
            uv.data[i].uv=[(0,0),(1,0),(.5,1)][loop.vertex_index]
        obj=bpy.data.objects.new("Gable",mesh)
        bpy.context.collection.objects.link(obj)
        paint(obj,wall,"Gable")
    for x in (-1.43,1.43):
        for y in (-1.09,1.09):
            box("Corner beam",(x,y,1.17),(.14,.14,1.86),wood)
    for z in (.27,1.98):
        box("Front beam",(0,-1.17,z),(3.03,.12,.14),wood)
    box("Door",(0,-1.2,.87),(.76,.12,1.22),wood)
    box("Doorstep",(0,-1.38,.1),(.93,.46,.20),stone)
    for x in (-.99,.99):
        box("Window frame",(x,-1.2,1.35),(.65,.13,.72),wood)
        box("Window",(x,-1.28,1.35),(.49,.045,.56),glass)
        box("Mullion",(x,-1.31,1.35),(.065,.045,.56),wood)
        box("Sill",(x,-1.32,1.06),(.72,.22,.09),wood)
    box("Chimney",(.95,.45,2.72),(.38,.42,1.0),stone)
    box("Chimney cap",(.95,.45,3.2),(.49,.52,.13),stone)

def tree():
    bark=material("Wood",(.35,.19,.09), 6)
    leaf1=material("Leaf",(.22,.42,.14), 7)
    leaf2=material("LeafLight",(.39,.57,.19), 8)
    cone("Trunk",(0,0,.8),.22,.13,1.6,bark)
    for loc,size,mat in [
        ((0,0,1.95),(.9,.78,.8),leaf1),
        ((-.42,-.12,1.65),(.64,.64,.58),leaf2),
        ((.43,.18,1.85),(.67,.56,.63),leaf1),
        ((.03,.02,2.49),(.62,.58,.64),leaf2)]:
        rock("Canopy",loc,size,mat)

def bench():
    wood=material("Wood",(.56,.31,.13),9)
    dark=material("Support",(.23,.15,.10),10)
    for x in (-.69,.69):
        for y in (-.2,.2):
            box("Leg",(x,y,.235),(.14,.14,.47),dark)
        box("Back support",(x,.23,.67),(.12,.12,.69),dark)
    for y in (-.22,-.07,.08,.23):
        box("Seat slat",(0,y,.51),(1.72,.135,.10),wood)
    for z in (.79,1.01):
        box("Back slat",(0,.25,z),(1.72,.10,.18),wood)

def export(name):
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes: o.select_set(True)
    path=OUT/(name+".glb")
    bpy.ops.export_scene.gltf(filepath=str(path.resolve()), export_format="GLB", use_selection=True)
    with path.open("rb") as f:
        magic, version, length=struct.unpack("<4sII",f.read(12))
        chunk_len, kind=struct.unpack("<I4s",f.read(8))
        assert magic==b"glTF" and version==2 and length==path.stat().st_size and kind==b"JSON"
        data=json.loads(f.read(chunk_len))
    assert data.get("meshes") and data.get("images"), "Missing mesh or texture"
    print(f"Validated {path}: {len(meshes)} objects, {len(data['images'])} textures")

def preview(name, target, distance):
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=64
    # Ubuntu Blender packages may be compiled without OpenImageDenoise.
    scene.cycles.use_denoising=False
    scene.render.resolution_x=640
    scene.render.resolution_y=480
    scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new("World")
    scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value=(.58,.64,.73,1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value=.45
    ground=material("Ground",(.35,.42,.31),11)
    box("Preview ground",(0,0,-.075),(200,200,.1),ground)
    bpy.ops.object.camera_add(location=Vector(target)+Vector((4,-6,4.8)).normalized()*distance)
    cam=bpy.context.object
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat("-Z","Y").to_euler()
    cam.data.type="ORTHO"
    cam.data.ortho_scale=distance*.62
    scene.camera=cam
    bpy.ops.object.light_add(type="AREA",location=(1,-4,7))
    light=bpy.context.object
    light.data.energy=750
    light.data.shape="DISK"
    light.data.size=5
    light.rotation_euler=(Vector(target)-light.location).to_track_quat("-Z","Y").to_euler()
    scene.render.image_settings.file_format="PNG"
    scene.render.filepath=str((OUT/(name+".png")).resolve())
    bpy.ops.render.render(write_still=True)

for name, build, target, distance in [
    ("house",house,(0,0,1.4),8),
    ("tree",tree,(0,0,1.45),5.8),
    ("bench",bench,(0,0,.55),4)]:
    reset()
    build()
    export(name)
    preview(name,target,distance)
