# asc-ImageJ-Unravel
 ImageJ/FIJI macro to This macro unravels an outline (aimed at curved surfaces) so that x coordinates are relative to adjacent pixels and y coordinates are relative to a single point (or line - not activated yet).
 <br />
 The <strong>asc-Unravel_Interface.ijm</strong> macro unravels a continuous outline so that coordinates of the pixel sequence can be exported. The original aim of this macro was to provide a tool to help generate the roughness of an interface in a cross-sectional 2D image.<br />
 The method originates in an idea proposed by Jeremy Adler (jeremy.adler==at==IGP.UU.SE) from an imageJ mailing list post on Monday, August 15, 2022 4:17 AM
 <br />
<p>We would like to extract the surface roughness from cross-sectional images like the one shown below:</p>
<p><img src="/images/asc-Unravel_RoughnessInterfaceSchematic_387w.png" alt="Interface schematic to show the problem to be solved by the Unravel macro" width="387" /> </p>

The "Unravel" macro can obtain a sequence of perimeter points that can be used as a profile and then Radial "Heights" can be obtained relative to the object center or any other reference point (or polar coordinates can be used). A 32-bit pseudo-height map can then be exported from the macro so that it can then be imported into dedicated surface roughness software analysis software like <a href="http://gwyddion.net/">Gwyddion</a>, enabling a comprehensive roughness analysis.

<p><img src="/images/asc-Unravel_pHMap_512w.png" alt="Pseudo-height-map generated for a filament cross-section by the Unravel macro." height="51" /> </p>

<br />
  <p>Sampling length is important for extracting roughness values and sample length can be derived from the overall shape or the cumulative pixel=pixel distance:</p>
<p><img src="/images/Unravel_Menu1_480w.png" alt="Unravel menu 1" width="480" /> </p>

<p>Evaluation lengths can be estimated for a variety of topologies:</p>

<p><img src="/images/Unravel_Menu2-CircOutline_510w.png" alt="Unravel menu 2" width="338" /> </p>

<p>The start points can be chosen automatically or manually and also the direction of the sequence:</p>

<p><img src="/images/Unravel_Menu3-CircOutline_681w.png" alt="Unravel menu 3" width="355" /> </p>

<p>The reference location(s) for the 'height' measurements can be selected:</p>

<p><img src="/images/Unravel_HeightRefMenu-CircOutline_500w.png" alt="Height referencing" width="500" /> </p>

<p>A pseudo-height map can be generated for import into dedicatedsurface analysis software:</p>

<p><img src="/images/asc-Unravel_pHMap_512w.png" alt="Height referencing" width="512" /> </p>

<p>The generated 32-bit height maps can be imported into Gwyddion for analysis:</p>
<p><img src="/images/Gwyddion_import_example_417w.png" alt="Gwyddion analysis of pseudo-height-map." width="417" /> </p>
<p><img src="/images/Unravel_Gwyddion-CircOutline_screenshot_764w.png" alt="Gwyddion projection" width="764" /> </p>
<p>Enabling a comprehensive roughness analysis:</p>
<p><img src="/images/Unravel_GwyddionAnalysis_1101w.png" alt="Gwyddion analysis of pseudo-height-map." width="1101" /> </p>
<br />
 <strong>Legal Notice:</strong> <br />
These macros have been developed to demonstrate the power of the ImageJ macro language and we assume no responsibility whatsoever for its use by other parties, and make no guarantees, expressed or implied, about its quality, reliability, or any other characteristic. On the other hand we hope you do have fun with them without causing harm.
<br />
The macros are continually being tweaked and new features and options are frequently added, meaning that not all of these are fully tested. Please contact me if you have any problems, questions or requests for new modifications.
 </sup></sub>
</p>
