import sys; sys.path.insert(0, '.')
from common import *
from mathutils import Vector, Euler
import os

def sphere(name, r, loc, m, scale=(1,1,1), seg=48):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=seg, ring_count=seg//2)
    o = bpy.context.object; o.name = name; o.scale = scale
    bpy.ops.object.shade_smooth(); o.data.materials.append(m); return o

def capsule(name, r, length, loc, m, rot=(0,0,0)):
    """smooth capsule: cylinder + two sphere caps joined as one object"""
    parts = []
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=length, location=(0,0,0), vertices=48)
    parts.append(bpy.context.object)
    for sz in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(0,0,sz*length/2), segments=48, ring_count=24)
        parts.append(bpy.context.object)
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object; o.name = name
    bpy.ops.object.shade_smooth()
    o.location = loc; o.rotation_euler = rot
    o.data.materials.append(m)
    return o

def torus_arc(name, R, r, loc, m, rot, deg=140):
    # smile: partial torus via curve circle -> use screw: build a bezier arc curve with bevel
    c = bpy.data.curves.new(name, 'CURVE'); c.dimensions = '3D'
    sp = c.splines.new('POLY'); n = 24
    sp.points.add(n)
    for i in range(n+1):
        a = math.radians(-deg/2 + deg*i/n)
        sp.points[i].co = (R*math.sin(a), 0, -R*math.cos(a)+R, 1)
    c.bevel_depth = r; c.bevel_resolution = 6; c.use_fill_caps = True
    o = bpy.data.objects.new(name, c); bpy.context.collection.objects.link(o)
    o.location = loc; o.rotation_euler = rot; o.data.materials.append(m); return o

class Mats:
    def __init__(s, skin, hair, suit, suit2, boots):
        s.skin = mat('skin', hexc(skin), rough=0.45, coat=0.15)
        s.hair = mat('hair', hexc(hair), rough=0.35, coat=0.3)
        s.suit = mat('suit', hexc(suit), rough=0.6, coat=0.0)
        s.suit2 = mat('suit2', hexc(suit2), rough=0.55, coat=0.0)
        s.boots = mat('boots', hexc(boots), rough=0.4, coat=0.3)
        s.white = mat('white', hexc('#FFFFFF'), rough=0.25, coat=0.5)
        s.dark = mat('dark', hexc('#1A1230'), rough=0.2, coat=0.6)
        s.iris = mat('iris', hexc('#2A78D8'), rough=0.2, coat=0.6)
        s.cheek = mat('cheek', hexc('#FF7A6B'), rough=0.6, coat=0)
        s.mouth = mat('mouth', hexc('#7A1F2A'), rough=0.4, coat=0.2)
        s.teeth = mat('teeth', hexc('#FFFFFF'), rough=0.3, coat=0.3)

def head(M, loc=(0,0,0), hair_style='quiff', eye_shift=(0,0), smile=1.0, iris=None):
    x, y, z = loc
    sphere('head', 1.0, (x, y, z), M.skin, scale=(1.0, 0.95, 0.96))
    # ears
    for sx in (-1, 1):
        sphere('ear', 0.2, (x + sx*0.97, y + 0.02, z - 0.02), M.skin, scale=(0.6, 0.9, 1.0))
    # eyes
    for sx in (-1, 1):
        ex = x + sx*0.36
        sphere('eye', 0.27, (ex, y - 0.82, z + 0.12), M.white, scale=(1, 0.55, 1.15))
        sphere('iris', 0.15, (ex + eye_shift[0]*0.05, y - 0.97, z + 0.12 + eye_shift[1]*0.05), iris or M.iris, scale=(1, 0.35, 1.1))
        sphere('pupil', 0.085, (ex + eye_shift[0]*0.05, y - 1.03, z + 0.12 + eye_shift[1]*0.05), M.dark, scale=(1, 0.3, 1.1))
        sphere('hl', 0.04, (ex + 0.05 + eye_shift[0]*0.05, y - 1.07, z + 0.19 + eye_shift[1]*0.05), M.white, scale=(1, 0.3, 1))
        # brow
        capsule('brow', 0.07, 0.34, (ex - sx*0.02, y - 0.84, z + 0.5), M.hair, rot=(0, math.radians(90) + sx*0.28, 0))
        # cheek
        sphere('cheek', 0.17, (x + sx*0.62, y - 0.72, z - 0.22), M.cheek, scale=(1, 0.3, 0.7))
    # nose
    sphere('nose', 0.17, (x, y - 0.97, z - 0.1), M.skin, scale=(1, 0.8, 0.85))
    # mouth
    sphere('mouth', 0.3, (x, y - 0.86, z - 0.42), M.mouth, scale=(1.0, 0.35, 0.62))
    sphere('tongue', 0.2, (x, y - 0.93, z - 0.55), mat('tongue', hexc('#FF6B7A'), rough=0.4), scale=(1.0, 0.3, 0.5))
    sphere('teeth', 0.27, (x, y - 0.97, z - 0.32), M.teeth, scale=(1.0, 0.18, 0.26))
    # hair
    if hair_style == 'quiff':
        sphere('hair', 1.02, (x, y + 0.08, z + 0.2), M.hair, scale=(1.0, 0.92, 0.95))
        sphere('quiff', 0.55, (x + 0.1, y - 0.55, z + 0.95), M.hair, scale=(1.5, 0.9, 0.75))
        sphere('quiff2', 0.4, (x + 0.55, y - 0.35, z + 0.82), M.hair, scale=(1.3, 0.9, 0.8))
        # fringe sideburn
        for sx in (-1, 1):
            sphere('side', 0.28, (x + sx*0.92, y - 0.15, z - 0.05), M.hair, scale=(0.5, 0.8, 1.2))
    elif hair_style == 'bun':
        sphere('hair', 1.04, (x, y + 0.12, z + 0.18), M.hair, scale=(1.02, 0.95, 0.97))
        sphere('bangs', 0.7, (x - 0.3, y - 0.5, z + 0.75), M.hair, scale=(1.5, 0.8, 0.6))
        sphere('bangs2', 0.6, (x + 0.5, y - 0.45, z + 0.7), M.hair, scale=(1.3, 0.8, 0.6))
        sphere('bun', 0.42, (x, y + 0.2, z + 1.1), M.hair)
        for sx in (-1, 1):
            sphere('lock', 0.34, (x + sx*0.95, y - 0.1, z - 0.25), M.hair, scale=(0.6, 0.8, 1.6))

def body(M, loc=(0,0.05,-2.1), badge=True):
    x, y, z = loc
    sphere('torso', 1.0, (x, y, z - 0.05), M.suit, scale=(0.86, 0.62, 0.92))
    sphere('hips', 1.0, (x, y, z - 0.62), M.suit, scale=(0.82, 0.6, 0.55))
    # belt
    bpy.ops.mesh.primitive_torus_add(major_radius=0.8, minor_radius=0.075, location=(x, y, z - 0.42), major_segments=64, minor_segments=16)
    t = bpy.context.object; t.scale = (1.0, 0.74, 1.0); bpy.ops.object.shade_smooth(); t.data.materials.append(M.suit2)
    rbox('buckle', (0.26, 0.06, 0.2), 0.04, loc=(x, y - 0.6, z - 0.42), m=mat('gold', hexc('#FFC21A'), rough=0.25, metal=0.6, coat=0.5))
    for sx in (-1, 1):
        rbox('pocket', (0.34, 0.08, 0.32), 0.05, loc=(x + sx*0.38, y - 0.56, z + 0.1), m=M.suit2)
    if badge:
        rbox('badge', (0.3, 0.05, 0.2), 0.03, loc=(x - 0.42, y - 0.6, z + 0.5), m=M.white)
    # zipper
    capsule('zip', 0.025, 1.1, (x, y - 0.6, z + 0.2), M.suit2)
    # neck + collar
    capsule('neck', 0.28, 0.2, (x, y - 0.02, z + 0.85), M.skin)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.46, minor_radius=0.13, location=(x, y - 0.02, z + 0.8), major_segments=48, minor_segments=16)
    c = bpy.context.object; c.scale = (1.0, 0.85, 0.7); bpy.ops.object.shade_smooth(); c.data.materials.append(M.suit2)
    # legs and boots
    for sx in (-1, 1):
        capsule('leg', 0.3, 0.7, (x + sx*0.36, y, z - 1.35), M.suit)
        sphere('boot', 0.42, (x + sx*0.36, y - 0.2, z - 1.95), M.boots, scale=(0.9, 1.25, 0.62))
        sphere('sole', 0.42, (x + sx*0.36, y - 0.2, z - 2.12), M.suit2, scale=(0.94, 1.3, 0.22))

def arm(M, shoulder, hand, thick=0.24):
    s = Vector(shoulder); h = Vector(hand)
    mid = (s + h) / 2
    d = h - s
    L = d.length
    o = capsule('arm', thick, L, mid, M.suit)
    o.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    sphere('hand', thick*1.15, hand, M.skin)
    sphere('cuff', thick*1.12, tuple(h - d.normalized()*thick*1.05), M.suit2, scale=(1,1,0.6))

def person(M, hair_style, pose='wave', eye_shift=(0,0), iris=None):
    head(M, (0, 0, 0), hair_style, eye_shift, iris=iris)
    body(M, (0, 0.05, -1.95))
    sx = 0.95
    if pose == 'wave':
        arm(M, (-sx, 0, -1.5), (-1.55, -0.35, -0.2))
        arm(M, (sx, 0, -1.5), (1.45, -0.6, -2.3))
    elif pose == 'hold':
        arm(M, (-sx, 0, -1.5), (-0.7, -1.0, -1.7))
        arm(M, (sx, 0, -1.5), (0.7, -1.0, -1.7))
    elif pose == 'think':
        arm(M, (-sx, 0, -1.5), (-0.5, -1.0, -1.35))
        arm(M, (sx, 0, -1.5), (1.4, -0.4, -2.3))
    elif pose == 'point':
        arm(M, (sx, 0, -1.5), (1.9, -0.9, -0.8))
        arm(M, (-sx, 0, -1.5), (-1.3, -0.3, -2.4))
    else:
        arm(M, (-sx, 0, -1.5), (-1.3, -0.3, -2.4))
        arm(M, (sx, 0, -1.5), (1.3, -0.3, -2.4))

def studio(target=(0,0,-1.2)):
    world((0.62, 0.7, 0.95), 0.55)
    light('AREA', (-4, -6, 4), 1300, size=6, target=target)
    light('AREA', (6, -3, 1), 450, size=6, color=(0.8, 0.88, 1), target=target)
    light('AREA', (0, 5, 3), 500, size=6, color=(1, 0.9, 0.8), target=target)

if __name__ == '__main__':
    OUT = sys.argv[1]; which = sys.argv[2]
    sc = reset(); sc.eevee.use_raytracing = False
    studio()
    if which == 'pip':
        M = Mats('#FF9A3C', '#7A3B1E', '#D9C8A6', '#B29A74', '#6B3A22')
        person(M, 'quiff', pose='wave')
    else:
        M = Mats('#FF9A3C', '#C2331E', '#D9C8A6', '#B29A74', '#6B3A22')
        person(M, 'bun', pose='think', iris=mat('iris2', hexc('#3B8A3B'), rough=0.2, coat=0.6))
    camera((0, -14, -1.1), (0, 0, -1.1), ortho=6.2)
    render(OUT, 800, 900)
