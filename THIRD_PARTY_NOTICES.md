# Third-party software notices

The CSASS release contains project code together with benchmark definitions,
comparison implementations, and dependencies from other authors. Existing
copyright and attribution headers are retained. No blanket MIT or other
replacement license is applied to third-party files. MATLAB and its toolboxes
are required separately and are not distributed in this release.

## PlatEMO

Benchmark definitions, utility functions, base classes, and comparison
implementations were obtained from BIMK/PlatEMO at commit
`d25e65d1ffba58dbf4d7e1b5259786187d12968a`. The retained protocol implementations
include study-specific initialization and evaluation-budget handling; the
protocol sources, rather than a different current PlatEMO installation, define
the experiments in this package.

The source headers and official README identify the BIMK Group as copyright
holder, permit research use, and require publications to acknowledge PlatEMO
and cite:

Ye Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin. PlatEMO: A MATLAB platform for
evolutionary multi-objective optimization [educational forum]. IEEE
Computational Intelligence Magazine, 12(4):73–87, 2017.

Official source and terms:
https://github.com/BIMK/PlatEMO/blob/d25e65d1ffba58dbf4d7e1b5259786187d12968a/README.md

The upstream uses its research-use statement rather than a general MIT/BSD
license. This package does not grant broader rights in those files.

## LIBSVM

HeEMOEA uses `svmtrain.mexw64` and `svmpredict.mexw64` shipped with its PlatEMO
source. These are Windows 64-bit MATLAB binaries. Their original build version
is not inferred from the binary names. The original binaries are retained
without recompilation, and the release file manifest identifies their hashes.

The complete official redistribution notice is included as
`licenses/LIBSVM_COPYRIGHT.txt`, from:
https://www.csie.ntu.edu.tw/~cjlin/libsvm/COPYRIGHT

Project: https://www.csie.ntu.edu.tw/~cjlin/libsvm/

## SURROGATES Toolbox

The `srgts*.m` functions used by MO-L2SMEA retain Felipe A. C. Viana's source
headers and redistribution/no-warranty statement. The author's official page
permits redistribution and modification and requests citation of the user's
guide:

F. A. C. Viana. SURROGATES Toolbox User's Guide, Version 2.1, 2010.

Official source and terms:
https://sites.google.com/site/felipeacviana/surrogates-toolbox

## DACE

The MO-L2SMEA Kriging dependency includes DACE routines by S. N. Lophaven,
H. B. Nielsen, and J. Søndergaard, as distributed in the retained upstream
source. Existing author and update notices remain in these files. The official
project makes software and documentation available free of charge; commercial
sale, including incorporation into other software, requires the authors'
prior written agreement.

Official source and terms: https://www.omicron.dk/dace.html

These notices identify the included components and preserve their upstream
terms. They are not a replacement license for any component.
