#!/usr/bin/python3
from PIL import Image

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


def generate_simple(size, name):
    pass



def generate(size, scaling):
    generate_simple(int(size*scaling), f"Icon-App-{size}x{size}@{scaling}x.png")


background.close()
