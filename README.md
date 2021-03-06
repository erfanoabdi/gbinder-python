# Cython extension module for ``gbinder``

## Prerequisites
* libgbinder
* libglibutil
* pkgconf

For development, you will also need Cython:
```bash
pip install cython
```

## Description

There are two Cython files: `cgbinder.pxd` describing the C++ API of the `libgbinder` library, and `gbinder.pyx` describing classes that will be visible from Python user code. 
The `.pyx` imports `.pxd` to learn about C functions available to be called.

There is also `setup.py` file. 
This file describes how to build the extension module, using `distutils`.
In there, we specify the library to link with as `libraries=['gbinder']`. The `gbinder` stands for `libgbinder.so` that we previously installed.

There are two options to build the package:
- One, use Cython's `cythonize()` function to generate a `.c` file from the `.pyx` one, and then compile it against the `libgbinder.so` library.
- Two, if the `.c` is already provided, just compile it - no Cython required!

## Development build

For development, use option 1 by providing `--cython` flag:

```bash
python setup.py build_ext --inplace --cython
```

The result will be a `.so` shared library named like `gbinder.cpython-38-x86_64-linux-gnu.so`. 
`build_ext` means we're building a C++ extension. `--inplace` means to put it in the current directory.
If you run `python` from current directory, you'll be able to `import gbinder`.

## Distribute

To distribute, call `sdist` with `--cython` flag to create source distribution (unbuilt):

```bash
python setup.py sdist --cython
```

The result will be a `dist/` directory with a distribution named like `gbinder-python-*.tar.gz` inside.
The archive contains `setup.py` and `gbinder.c`, so users can build and install it without having Cython!

To publish to PyPI, run:

```bash
twine upload -r pypi dist/*
```

## Install

To install, locate the `.tar.gz` distribution and run:
```bash
pip install dist/gbinder-python-*.tar.gz
```

###### Readme and setup.py is based on [`geographiclib-cython-bindings` repo](https://github.com/megaserg/geographiclib-cython-bindings/blob/master/README.md) thanks to @megaserg
