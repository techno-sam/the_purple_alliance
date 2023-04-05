#!/usr/bin/python3
from PIL import Image
import os

resolutions = [
    (20, (1, 3)),
    (29, (1, 3)),
    (40, (1, 3)),
    (60, (2, 3)),
    (76, (1, 2)),
    (83.5, 2),
    (1024, 1),
    ]


background = Image.open("569bf1c5-d6c3-4656-8440-bba1b6fcee07.png")
print(background.format, background.size, background.mode)
#background.resize((16, 16)).show()
os.makedirs("out", exist_ok=True)


def generate_simple(size, name):
    sized_bg = background.resize((size, size))
#    sized_bg.show()
    # time to convert svg
    fg_scale = 0.75
    fg_size = round(size*fg_scale)
    offset = round((size-(size*fg_scale))/2)
    os.system(f"inkscape --export-width={fg_size} --export-height={fg_size} --export-type=png --export-filename=fg_tmp.png binoculars-svgrepo-com-white.svg")
    fg = Image.open("fg_tmp.png")
    im = Image.new("RGBA", (size, size))
    bg_offset = round((2048-size)/2)
    #im.paste(background, box=(-bg_offset, -bg_offset))
    im.paste(sized_bg)
    print(fg.mode)
    r, g, b, _ = fg.split()
    fg2 = Image.merge("RGB", (r, g, b))#fg#.point(lambda i: round(i*1.05))
    im.paste(fg2, mask=fg, box=(offset, offset))
    im.save(os.path.join("out", name))



def generate(size, scaling):
    generate_simple(int(size*scaling), f"Icon-App-{size}x{size}@{scaling}x.png")


for base, more in resolutions:
    if type(more) == tuple:
        # start - end (inclusive)
        for scale in range(more[0], more[1]+1):
            generate(base, scale)
    elif type(more) == int:
        generate(base, more)
    else:
        raise ValueError(f"Inappropriate scaling parameter {more}")


background.close()
