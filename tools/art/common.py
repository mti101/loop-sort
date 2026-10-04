import bpy, math, sys
from mathutils import Vector

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    try:
        sc.eevee.taa_render_samples = 64
        sc.eevee.use_raytracing = True
    except Exception: pass
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.view_settings.view_transform = 'Standard'
    return sc

def world(color=(0.55,0.62,0.85), strength=1.0):
    w = bpy.data.worlds.new('w'); bpy.context.scene.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes['Background']
    bg.inputs[0].default_value = (*color, 1); bg.inputs[1].default_value = strength

def mat(name, color, rough=0.25, metal=0.0, coat=0.6, emit=None, spec=0.5):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    for k, v in (('Coat Weight', coat), ('Coat Roughness', 0.08), ('Specular IOR Level', spec)):
        if k in b.inputs: b.inputs[k].default_value = v
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = 1.0
    return m

def hexc(h):
    h = h.lstrip('#'); r, g, b = [int(h[i:i+2], 16)/255 for i in (0, 2, 4)]
    f = lambda c: ((c+0.055)/1.055)**2.4 if c > 0.04045 else c/12.92
    return (f(r), f(g), f(b))

def light(kind, loc, energy, size=2, color=(1,1,1), rot=None, target=None):
    d = bpy.data.lights.new('l', kind); d.energy = energy
    if kind == 'AREA': d.size = size
    if kind == 'SUN': d.angle = 0.2
    d.color = color
    o = bpy.data.objects.new('l', d); bpy.context.collection.objects.link(o)
    o.location = loc
    if target:
        dirv = Vector(target) - Vector(loc); o.rotation_euler = dirv.to_track_quat('-Z', 'Y').to_euler()
    if rot: o.rotation_euler = rot
    return o

def camera(loc, target, ortho=None, lens=50):
    c = bpy.data.cameras.new('c')
    if ortho: c.type = 'ORTHO'; c.ortho_scale = ortho
    else: c.lens = lens
    o = bpy.data.objects.new('c', c); bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = o
    return o

def rbox(name, size, radius, loc=(0,0,0), m=None, seg=6, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object; o.name = name
    o.scale = size; o.rotation_euler = rot
    bpy.ops.object.transform_apply(scale=True)
    bv = o.modifiers.new('bv', 'BEVEL'); bv.width = radius; bv.segments = seg; bv.limit_method = 'NONE'
    bpy.ops.object.shade_smooth()
    if m: o.data.materials.append(m)
    return o

def render(path, w, h, samples=None):
    sc = bpy.context.scene
    sc.render.resolution_x = w; sc.render.resolution_y = h
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
