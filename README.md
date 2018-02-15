# MeshAssembler

## Install

Download and install the [unitypackage](https://github.com/theepicsnail/MeshAssembler/blob/master/MeshAssembler.unitypackage)

The shader is placed under Assets/Snail/MeshAssembler

## Use

**DebugValue**

Should be 0 for your actual usage. You can move it up or down to see what the shader looks like at different degrees of assembly

**Texture**

The texture to apply (Uses your meshes uvs like normal)

**Movement**

How much pieces should move during assembly, this also controls how much the wiggle while you're standing still.

**Visible/Invisible**

These are the distances that your mesh is fully assembled(visible) or fully disassembled(invisible). 
They work in either direction.

If visible < invisible:
*  It will be invisible when you're far away.
*  It turns visible approach it.

If visible > invisible:
*  It will be visible when you're far away.
*  It turns invisible as you approach it.
