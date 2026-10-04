import sys; sys.path.insert(0, '.')
from chars import *

def puppy(loc=(0,0,0), scale=1.0, look=0.0):
    x, y, z = loc
    fur = mat('fur', hexc('#C9833E'), rough=0.6, coat=0.1)
    fur2 = mat('fur2', hexc('#7A4524'), rough=0.6, coat=0.1)
    cream = mat('cream', hexc('#FFE9C7'), rough=0.6, coat=0.1)
    nose = mat('nose', hexc('#1A1230'), rough=0.2, coat=0.7)
    band = mat('band', hexc('#E8333F'), rough=0.5)
    s = scale
    # body
    sphere('body', 1.0*s, (x, y, z), fur, scale=(0.75, 1.2, 0.7))
    sphere('belly', 1.0*s, (x, y - 0.25*s, z - 0.12*s), cream, scale=(0.5, 0.9, 0.5))
    # head
    hx, hy, hz = x, y - 1.15*s, z + 0.55*s
    sphere('head', 0.62*s, (hx, hy, hz), fur, scale=(1, 0.95, 0.92))
    sphere('muzzle', 0.34*s, (hx, hy - 0.45*s, hz - 0.12*s), cream, scale=(1, 0.9, 0.7))
    sphere('nose', 0.12*s, (hx, hy - 0.74*s, hz - 0.02*s), nose, scale=(1.2, 0.8, 0.8))
    for sx in (-1, 1):
        sphere('ear', 0.3*s, (hx + sx*0.6*s, hy + 0.05*s, hz + 0.05*s), fur2, scale=(0.45, 0.7, 1.15))
        sphere('eye', 0.12*s, (hx + sx*0.25*s, hy - 0.52*s, hz + 0.18*s), mat('w', hexc('#FFFFFF'), rough=0.2, coat=0.5), scale=(1, 0.5, 1.1))
        sphere('pup', 0.07*s, (hx + sx*0.25*s + look*0.02, hy - 0.58*s, hz + 0.18*s), nose, scale=(1, 0.4, 1.1))
        sphere('hl', 0.025*s, (hx + sx*0.25*s + 0.03*s, hy - 0.62*s, hz + 0.23*s), mat('w2', hexc('#FFFFFF'), rough=0.2), scale=(1, 0.4, 1))
        # legs
        sphere('leg', 0.22*s, (x + sx*0.42*s, y - 0.7*s, z - 0.55*s), fur, scale=(1, 1, 1.5))
        sphere('leg', 0.22*s, (x + sx*0.42*s, y + 0.7*s, z - 0.55*s), fur, scale=(1, 1, 1.5))
        sphere('paw', 0.25*s, (x + sx*0.42*s, y - 0.78*s, z - 0.92*s), cream, scale=(1, 1.2, 0.6))
        sphere('paw', 0.25*s, (x + sx*0.42*s, y + 0.62*s, z - 0.92*s), cream, scale=(1, 1.2, 0.6))
    sphere('tongue', 0.1*s, (hx, hy - 0.66*s, hz - 0.36*s), mat('t', hexc('#FF6B7A'), rough=0.4), scale=(1, 0.4, 1.4))
    capsule('tail', 0.12*s, 0.7*s, (x + 0.3*s, y + 1.25*s, z + 0.35*s), fur, rot=(math.radians(-50), math.radians(25), 0))
    # bandana
    bpy.ops.mesh.primitive_torus_add(major_radius=0.5*s, minor_radius=0.12*s, location=(hx, hy + 0.35*s, hz - 0.5*s), major_segments=40, minor_segments=14)
    t = bpy.context.object; t.scale = (1, 0.9, 0.8); bpy.ops.object.shade_smooth(); t.data.materials.append(band)

if __name__ == '__main__':
    sc = reset(); sc.eevee.use_raytracing = False
    studio((0, 0, 0))
    puppy()
    camera((0, -12, 3), (0, -0.4, 0), ortho=4.8)
    render(sys.argv[1], 700, 700)
