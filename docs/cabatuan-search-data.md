# Cabatuan barangay search data

The offline navigation bounds cover all 68 names in `LocationConstants.cabatuanBarangays`, shared with `veri_form.dart`.
Bounds are calculated from the published polygons, not guessed coordinates. They guide map zoom; users still draw their own farm boundary.

Source: https://github.com/bendlikeabamboo/barangay-boundaries-repository/blob/main/2023-10-24/hierarchical_t0p005/barangays.geojson

Attribution: Philippine Statistics Authority (PSGC names/codes); NAMRIA administrative boundaries, validOn 2023-11-06; enrichment by bendlikeabamboo.
Snapshot: 2023-10-24. Upstream geometries are simplified at 0.005 degrees.
Downloaded Cabatuan subset SHA-256: `0cf7c1266b32869922316cf1783a3f7c9bce139eb65ae468f857a5c0d5855359`.

Name matching removes punctuation/case only: Duyanduyan → Duyan-Duyan, Pamul-Ogan → Pamul-ogan, and spacing in Zone VI are normalized to the app's registration labels.

To regenerate, download the source, filter municipality `ADM3_PCODE = PH0603012`, then run:

`python scripts/generate_cabatuan_search_areas.py <cabatuan.geojson>`

## Upstream license

MIT License

Copyright (c) 2026 bendlikeabamboo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

