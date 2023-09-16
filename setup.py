import sys, subprocess
from distutils.core import setup, Extension


def pkgconfig(package, kw):
    flag_map = {'-I': 'include_dirs', '-L': 'library_dirs', '-l': 'libraries'}
    output = subprocess.getoutput(
        'pkg-config --cflags --libs {}'.format(package))
    for token in output.strip().split():
        kw.setdefault(flag_map.get(token[:2]), []).append(token[2:])
    return kw

USE_CYTHON = False
if "--cython" in sys.argv:
    sys.argv.remove("--cython")
    USE_CYTHON = True

file_ext = ".pyx" if USE_CYTHON else ".c"

extension_kwargs = { 'sources': ["gbinder" + file_ext] }
extension_kwargs = pkgconfig('libgbinder', extension_kwargs)
if None in extension_kwargs:
    del extension_kwargs[None]
extensions = [Extension('gbinder', **extension_kwargs)]

if USE_CYTHON:
    from Cython.Build import cythonize
    extensions = cythonize(extensions, compiler_directives={
                           'language_level': "3"})

setup(
    name="gbinder-python",
    description="""Cython extension module for C++ gbinder functions""",
    version="1.1.2",
    author="Erfan Abdi",
    author_email="erfangplus@gmail.com",
    url="https://github.com/erfanoabdi/gbinder-python",
    license="GPL3",
    ext_modules=extensions
)
