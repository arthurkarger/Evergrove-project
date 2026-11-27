"""Generate original, low-poly Evergrove props using Blender's Python API."""
import bpy
import numpy as np
import math
import random
import json
import struct
import sys
from pathlib import Path
from mathutils import Vector

GAME = "--game-assets" in sys.argv
OUT = Path("assets/models/generated" if GAME else "blender-output")
OUT.mkdir(parents=True, exist_ok=True)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, rgb, seed):
    rng = np.random.default_rng(seed)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = {"Glass": .26, "Roof": .77, "Wood": .83}.get(name, .93)
    size = 256 if name in ("Wood", "Stone", "Roof", "Plaster") else 128
    y, x = np.mgrid[:size,:size] * (math.tau / size)
    relief = .22*np.sin(x*3+np.sin(y*2)) * np.cos(y*4)
    if name in ("Wood", "Support"):
        grain = x*11 + 2*np.sin(y+np.sin(x)) + .6*np.sin(y*3+x*2)
        relief = .55*np.sin(grain)+.23*np.sin(grain*3)+.13*np.cos(grain*7)
    elif name == "Roof":
        row = np.floor(y/math.tau*4)
        relief = .7*np.minimum(1,np.abs(np.sin(y*2))*9) + .35*np.minimum(1,np.abs(np.sin(x*4+row*math.pi/2))*10)-.7
    elif name == "Stone":
        relief += .5*np.sin(x*2+np.sin(y*3)) + .13*np.cos(x*11-y*5)
    elif name.startswith(("Leaf","Needles")):
        relief = .48*np.sin(x*5+np.sin(y*3))*np.cos(y*6)+.27*np.sin(2*x-y)
    relief += .15*np.sin(x*1.0+y*2.0)+.10*np.cos(x*3.0-y)
    relief += rng.uniform(-.075,.075,(size,size))
    def texture(suffix, values, noncolor=False):
        img = bpy.data.images.new(name+suffix,width=size,height=size,alpha=False)
        if noncolor: img.colorspace_settings.name = "Non-Color"
        rgba = np.ones((size,size,4),dtype=np.float32)
        rgba[:,:,:3] = np.clip(values,0,1)
        img.pixels.foreach_set(rgba.ravel())
        img.pack()
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = img
        return tex.outputs["Color"]
    links.new(texture("_paint",np.asarray(rgb)*(1+.23*relief[:,:,None])),bsdf.inputs["Base Color"])
    if name in ("Wood","Stone","Roof","Plaster","Support"):
        dx = (np.roll(relief,1,1)-np.roll(relief,-1,1))*.35
        dy = (np.roll(relief,1,0)-np.roll(relief,-1,0))*.35
        normal = np.stack([dx,dy,np.ones_like(dx)],axis=-1)
        normal /= np.linalg.norm(normal,axis=-1,keepdims=True)
        bump = nodes.new("ShaderNodeNormalMap")
        links.new(texture("_normal",normal*.5+.5,True),bump.inputs["Color"])
        links.new(bump.outputs["Normal"],bsdf.inputs["Normal"])
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
    paint(obj, mat, name)
    bevel=obj.modifiers.new("Soft handcrafted edges", "BEVEL")
    bevel.width=min(.055, min(size)*.20)
    bevel.segments=3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj

def cone(name, loc, r1, r2, depth, mat, vertices=7):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=depth, location=loc)
    return paint(bpy.context.object, mat, name)

def rock(name, loc, size, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=loc)
    obj = bpy.context.object
    obj.scale = size
    for poly in obj.data.polygons: poly.use_smooth=True
    return paint(obj, mat, name)

def srgb(hex_color):
    def linear(v): return v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4
    return tuple(linear(int(hex_color[i:i+2],16)/255) for i in (0,2,4))

def house(roof_color=(.48,.16,.12), wall_color=(.81,.66,.43)):
    wall=material("Plaster", wall_color, 1)
    wood=material("Wood", (.29,.15,.075), 2)
    roof=material("Roof", roof_color, 3)
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
    box("Door inset",(0,-1.27,.93),(.52,.03,.88),wood)
    box("Doorstep",(0,-1.38,.1),(.93,.46,.20),stone)
    for x in (-.99,.99):
        box("Window frame",(x,-1.2,1.35),(.65,.13,.72),wood)
        box("Window",(x,-1.28,1.35),(.49,.045,.56),glass)
        box("Mullion",(x,-1.31,1.35),(.065,.045,.56),wood)
        box("Sill",(x,-1.32,1.06),(.72,.22,.09),wood)
    # A curved ridge, shutters and a small canopy give the facade depth.
    ridge=cone("Ceramic ridge",(0,0,2.91),.115,.115,3.52,roof,12)
    ridge.rotation_euler.y=math.pi/2
    box("Porch canopy",(0,-1.45,1.65),(1.2,.66,.12),roof,(.12,0,0))
    for x in (-.5,.5):
        box("Porch bracket",(x,-1.34,1.48),(.08,.33,.09),wood,(.58,0,0))
    for x in (-.99,.99):
        for side in (-1,1):
            box("Shutter",(x+side*.38,-1.23,1.35),(.14,.08,.71),roof)
        box("Window crossbar",(x,-1.32,1.38),(.52,.05,.055),wood)
    rock("Latch",(.23,-1.29,.89),(.04,.035,.04),stone)
    box("Chimney",(.95,.45,2.72),(.38,.42,1.0),stone)
    box("Chimney cap",(.95,.45,3.2),(.49,.52,.13),stone)

def tree(fruit=False):
    bark=material("Wood",(.35,.19,.09), 6)
    leaf1=material("Leaf",srgb("67983b"), 7)
    leaf2=material("LeafLight",srgb("a3c95a"), 8)
    cone("Trunk",(0,0,.85),.25,.14,1.7,bark,vertices=12)
    for loc,size,mat in [
        ((0,0,1.95),(.9,.78,.8),leaf1),
        ((-.42,-.12,1.65),(.64,.64,.58),leaf2),
        ((.43,.18,1.85),(.67,.56,.63),leaf1),
        ((.03,.02,2.49),(.62,.58,.64),leaf2)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1, location=loc)
        obj=bpy.context.object
        obj.scale=size
        for v in obj.data.vertices:
            p=v.co
            p *= 1+.045*math.sin(p.x*8+p.z*5)*math.cos(p.y*7)
        for poly in obj.data.polygons: poly.use_smooth=True
        paint(obj,mat,"Canopy")
    for side in (-1,1):
        fork=cone("Branch",(side*.23,0,1.21),.11,.07,.68,bark,10)
        fork.rotation_euler.y=side*.65
    for j in range(13):
        a=j*2.4
        rock("Crown lobe",(.69*math.cos(a),.59*math.sin(a),1.92+.38*math.sin(a*2)),
             (.29+.045*(j%3),.30,.30+.05*(j%2)),leaf2 if j%3==0 else leaf1)
    if fruit:
        apple=material("Apple",(.72,.22,.08),14)
        for loc in [(-.72,-.57,1.7),(.58,-.52,1.8),(.82,.18,1.86)]:
            rock("Fruit",loc,(.15,.15,.16),apple)
            cone("Fruit stem",(loc[0],loc[1],loc[2]+.15),.018,.013,.075,bark,vertices=8)

def pine():
    bark=material("Wood",(.35,.19,.09),16)
    cone("Trunk",(0,0,1),.33,.20,2,bark,vertices=12)
    for i, color in enumerate(["4a7443","679447","91b75d"]):
        leaf=material("Needles"+str(i),srgb(color),20+i)
        obj=cone("Needles",(0,0,1.9+i*.76),1.45-i*.305,.075,2,leaf,vertices=32)
        for vert in obj.data.vertices:
            a=math.atan2(vert.co.y,vert.co.x)
            if vert.co.z<0:
                vert.co.z+=.13*math.cos(6*a+i)
                vert.co.x*=1+.045*math.sin(5*a)
        for poly in obj.data.polygons:
            if len(poly.vertices)<=4: poly.use_smooth=True

def character_part(kind):
    mat=material("Neutral",(.7,.7,.7),40)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,radius=.5)
    obj=bpy.context.object
    for vert in obj.data.vertices:
        x,y,z=vert.co
        if kind=="head":
            # Round forehead and cheeks, slightly narrower jaw.
            x *= 1+.23*math.exp(-((z+.13)/.18)**2)-.21*max(0,-z)*2
            y *= 1-.12*max(0,-z)*2
        elif kind=="torso":
            x *= 1+.30*z+.06*math.cos(z*math.pi*2)
            z=math.copysign(.5*(abs(z)*2)**.70,z)
        elif kind=="limb":
            z=math.copysign(.5*(abs(z)*2)**.72,z)
        elif kind=="shoe":
            z=max(-.31,z)
            y *= 1-.32*z+.08*math.cos(x*math.pi*2)
        elif kind=="hair":
            z=math.copysign(.5*(abs(z)*2)**.82,z)
            y *= 1+.12*math.cos(x*12+z*4)
        vert.co=(x,y,z)
    for axis in range(3):
        lo=min(v.co[axis] for v in obj.data.vertices)
        hi=max(v.co[axis] for v in obj.data.vertices)
        for v in obj.data.vertices: v.co[axis]=(v.co[axis]-(lo+hi)*.5)/(hi-lo)
    for poly in obj.data.polygons: poly.use_smooth=True
    paint(obj,mat,kind)

# Original modular character meshes. Coordinates are Blender Z-up, front -Y.
def sculpt_mesh(name, verts, faces, mat):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    uv=mesh.uv_layers.new()
    for p in mesh.polygons:
        p.use_smooth=True
        for i in p.loop_indices:
            x,y,z=mesh.vertices[mesh.loops[i].vertex_index].co
            uv.data[i].uv=((math.atan2(y,x)/math.tau+.5),z+.5)
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    paint(obj,mat,name)
    return obj

def sweep(name, points, widths, depths, mat):
    # Tapered sculpted strands follow a curved centreline, not loose spheres.
    verts=[]; faces=[]; n=12
    for i,(x,y,z) in enumerate(points):
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
        tangent.normalize()
        across=Vector((0,-1,0)).cross(tangent)
        if across.length<.01: across=Vector((1,0,0))
        across.normalize()
        deep=tangent.cross(across).normalized()
        for j in range(n):
            a=math.tau*j/n
            v=Vector((x,y,z))+across*(widths[i]*math.cos(a))+deep*(depths[i]*math.sin(a))
            verts.append(tuple(v))
        if i:
            for j in range(n):
                k=(j+1)%n
                faces.append(((i-1)*n+j,(i-1)*n+k,i*n+k,i*n+j))
    faces.append(tuple(range(n-1,-1,-1)))
    faces.append(tuple(range((len(points)-1)*n,len(points)*n)))
    return sculpt_mesh(name,verts,faces,mat)

def hairstyle_model(style):
    mat=material("Neutral",(.7,.7,.7),40)
    n=40; rings=16; verts=[]; faces=[]
    for i in range(rings+1):
        for j in range(n):
            a=math.tau*j/n
            front=max(0,-math.sin(a))
            back=max(0,math.sin(a))
            edge=1.66-.64*front+.56*back
            if style in (1,3,4): edge+=.24*(1-front)
            if style==5: edge-=.12
            t=.018+(edge-.018)*i/rings
            ripple=1+.018*math.cos(9*a+t*3)
            verts.append((.418*math.sin(t)*math.cos(a)*ripple,.358*math.sin(t)*math.sin(a)*ripple+.018,.416*math.cos(t)+.026))
    for i in range(rings):
        for j in range(n):
            k=(j+1)%n
            faces.append((i*n+j,(i+1)*n+j,(i+1)*n+k,i*n+k))
    faces.append(tuple(range(n-1,-1,-1)))
    sculpt_mesh("Scalp silhouette",verts,faces,mat)
    # Layered swept fringe, with tapered tips and distinct silhouettes.
    ends=[(-.31,.10),(-.17,.17),(.01,.13),(.19,.19),(.32,.12)]
    if style in (1,3): ends=[(-.32,.07),(-.18,.22),(.02,.18),(.22,.14),(.32,.03)]
    if style==5: ends=[(-.31,.13),(-.16,.10),(0,.09),(.16,.10),(.31,.13)]
    for j,(x,z) in enumerate(ends):
        start_x=x*.46-.06
        sweep("Fringe",[(start_x,-.17,.37),(x*.66-.06,-.29,.31),(x*.92,-.343,.23),(x,-.31,z)],
              [.06,.105,.085,.008],[.035,.065,.05,.008],mat)
    if style in (1,3,4):
        for side in (-1,1):
            for j in range(3):
                x=side*(.28+j*.043)
                low=-.24 if style==1 else (-.42 if style==3 else -.50)
                sweep("Side wave",[(side*.24,-.04+j*.07,.24),(x,-.05+j*.08,.07),(x*1.12,-.06+j*.08,-.14),(x*.90,-.12+j*.08,low+.03*j),(x*.78,-.09+j*.08,low-.03)],
                      [.075,.105,.10,.075,.01],[.07,.09,.09,.055,.01],mat)
    if style==2:
        obj=rock("High bun",(0,.12,.43),(.22,.20,.21),mat)
        for j in range(5):
            a=j*math.tau/5
            rock("Bun coil",(.12*math.cos(a),.12+.12*math.sin(a),.46),(.12,.12,.15),mat)
    if style==4:
        for side in (-1,1):
            for j in range(5):
                rock("Braided lock",(side*(.33+.025*(-1)**j),.015+.025*(-1)**j,-.08-j*.085),(.09,.085,.085),mat)
    if style==5:
        for j in range(10):
            a=j*math.tau/10
            rock("Soft curl",(.30*math.cos(a),.25*math.sin(a),.28+.05*math.sin(3*a)),(.145,.135,.14),mat)
    if style==0:
        for side in (-1,1):
            sweep("Swept side",[(side*.21,.05,.31),(side*.36,.02,.19),(side*.43,-.02,.15)], [.10,.095,.008],[.055,.065,.008],mat)

def garment_model(kind):
    mat=material("Neutral",(.7,.7,.7),40)
    # Cross sections with sculpted drape, cuffs and hem, in normalized dimensions.
    profiles={
        "shirt":[(-.5,.46,.39),(-.43,.50,.44),(-.16,.46,.47),(.18,.46,.5),(.35,.49,.43),(.5,.26,.30)],
        "jacket":[(-.5,.45,.40),(-.40,.49,.48),(.0,.50,.5),(.28,.48,.46),(.44,.37,.36),(.5,.25,.25)],
        "dress":[(-.5,.50,.48),(-.41,.49,.47),(-.1,.40,.38),(.18,.34,.34),(.40,.32,.30),(.5,.24,.23)],
        "skirt":[(-.5,.50,.46),(-.43,.49,.45),(-.1,.39,.37),(.28,.30,.29),(.5,.27,.26)],
        "sleeve":[(-.5,.42,.42),(-.38,.46,.45),(.0,.49,.49),(.32,.50,.50),(.5,.34,.34)],
        "shorts":[(-.5,.44,.43),(-.42,.49,.48),(-.10,.50,.50),(.30,.49,.47),(.5,.42,.41)],
        "boots":[(-.5,.43,.48),(-.39,.49,.5),(-.16,.50,.49),(.04,.43,.46),(.28,.39,.37),(.5,.37,.34)],
    }
    n=32; verts=[]; faces=[]
    for z,rx,ry in profiles[kind]:
        for j in range(n):
            a=math.tau*j/n
            fold=1+(.065 if kind in ("skirt","dress") else .015)*math.cos(a*8)*(1-z)
            verts.append((rx*math.cos(a)*fold,ry*math.sin(a)*fold,z))
    for i in range(len(profiles[kind])-1):
        for j in range(n):
            k=(j+1)%n
            faces.append((i*n+j,i*n+k,(i+1)*n+k,(i+1)*n+j))
    faces.append(tuple(range(n-1,-1,-1)))
    faces.append(tuple(range((len(profiles[kind])-1)*n,len(profiles[kind])*n)))
    sculpt_mesh(kind,verts,faces,mat)

def bench():
    wood=material("Wood",(.56,.31,.13),9)
    dark=material("Support",(.23,.15,.10),10)
    for x in (-.69,.69):
        for y in (-.2,.2):
            box("Leg",(x,y,.235),(.14,.14,.47),dark)
        box("Back support",(x,.23,.67),(.12,.12,.69),dark)
    for y in (-.22,-.07,.08,.23):
        box("Seat slat",(0,y,.51),(1.72,.135,.10),wood)
    for z in (.76,.91,1.06):
        box("Back slat",(0,.25,z),(1.72,.10,.135),wood)
    for x in (-.79,.79):
        box("Armrest",(x,0,.76),(.13,.56,.12),dark)
        box("Arm support",(x,-.19,.62),(.10,.10,.26),dark)

def wildflowers():
    green=material("Leaf",srgb("6e9851"),75)
    cream=material("Petal",srgb("fff0b7"),76)
    amber=material("Pollen",srgb("e99e41"),77)
    for j in range(3):
        x=.22*math.cos(j*2.4)
        y=.2*math.sin(j*2.4)
        h=.35+.09*j
        cone("Stem",(x,y,h/2),.018,.011,h,green,8)
        rock("Basal leaf",(x+.055,y,h*.43),(.115,.05,.045),green).rotation_euler.y=-.52
        for k in range(7):
            a=k*math.tau/7+j
            petal=rock("Petal",(x+.086*math.cos(a),y+.086*math.sin(a),h),(.096,.047,.035),cream)
            petal.rotation_euler.z=a
        rock("Flower heart",(x,y,h+.026),(.057,.057,.038),amber)

def river_stones():
    stone=material("Stone",srgb("88999c"),78)
    moss=material("Leaf",srgb("90a361"),79)
    for x,y,z,w in [(0,0,.21,.47),(.32,.14,.12,.22),(-.28,-.16,.085,.18)]:
        obj=rock("River stone",(x,y,z),(w,w*.79,w*.7),stone)
        for v in obj.data.vertices:
            v.co.z=max(-.55,v.co.z)
            v.co.x+=.14*math.sin(v.co.y*4)
            v.co.y+=.06*math.cos(v.co.z*6)
        rock("Lichen",(x-.04,y+.02,z+w*.63),(w*.45,w*.38,.04),moss)

def furniture(kind):
    wood=material("Wood",srgb("bb8a59"),90)
    trim=material("Support",srgb("77503d"),91)
    if kind=="chest":
        box("Chest carcass",(0,0,.32),(.88,.73,.6),wood)
        box("Rounded lid",(0,0,.66),(.95,.79,.16),wood)
        for x in (-.29,.29):
            box("Binding",(x,0,.75),(.055,.77,.035),trim)
            box("Front binding",(x,-.37,.32),(.055,.025,.58),trim)
        box("Latch",(0,-.403,.55),(.14,.045,.14),trim)
        for x in (-.34,.34):
            box("Foot",(x,0,.035),(.15,.65,.09),trim)
    else:
        for x in (-.34,.34):
            for y in (-.30,.30):
                cone("Turned leg",(x,y,.26),.075,.095,.52,trim,12)
        for j in range(4):
            box("Table plank",(0,(j-1.5)*.2,.54),(.94,.194,.13),wood)
        for x in (-.34,.34):
            box("Apron",(x,0,.41),(.09,.68,.12),trim)

def export(name):
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes: o.select_set(True)
    if GAME and len(meshes)>1:
        bpy.context.view_layer.objects.active=meshes[0]
        bpy.ops.object.join()
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
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

if GAME:
    palettes=[("628693","f3d1a0"),("946e57","e6cfa8"),("96778c","efd0b5"),("577453","f3da9e"),("b76349","efd2a2"),("597e80","f0d8ab"),("84905d","eac398")]
    for roof,wall in palettes:
        reset()
        house(srgb(roof),srgb(wall))
        export("house_"+roof)
    for name,build in [("tree",tree),("pine",pine),("fruit_tree",lambda:tree(True)),("bench",bench),("wildflowers",wildflowers),("river_stones",river_stones),
                       ("table",lambda:furniture("table")),("chest",lambda:furniture("chest"))]:
        reset()
        build()
        export(name)
    for kind in ("head","torso","limb","shoe","hair"):
        reset()
        character_part(kind)
        export("character_"+kind)
    for style in range(6):
        reset()
        hairstyle_model(style)
        export("character_style_"+str(style))
    for kind in ("shirt","jacket","dress","skirt","sleeve","shorts","boots"):
        reset()
        garment_model(kind)
        export("character_garment_"+kind)
else:
    for name, build, target, distance in [
        ("house",house,(0,0,1.4),8),
        ("tree",tree,(0,0,1.45),5.8),
        ("bench",bench,(0,0,.55),4)]:
        reset()
        build()
        export(name)
        preview(name,target,distance)
