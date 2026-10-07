// MarchingBlocks Paint for Unity — THE ANIMATED MATERIALS OF A TILESET: for each material of tiles.glb that carries
// extras.mb_animation, the MarchingBlocks/Lit copy that plays it (its frames in Texture2DArrays). Made by the editor
// (Tools > MarchingBlocks, or Import World) next to the .mbset; a MarchingBlocksWorld that points at it swaps the
// materials of its tiles and gives every tile its PHASE (MBAnimation.PhaseOf of its origin, in format space).

using System.Collections.Generic;
using UnityEngine;

namespace MarchingBlocks.Paint
{
    public sealed class MBAnimatedSet : ScriptableObject
    {
        [System.Serializable]
        public struct Entry
        {
            [Tooltip("The material your glTF importer made (it shows frame 0).")] public Material source;
            [Tooltip("Its MarchingBlocks/Lit copy, animated.")] public Material animated;
        }

        public List<Entry> entries = new List<Entry>();

        /// <summary>The animated copy of a material, or the material itself when it is not animated.</summary>
        public Material Swap(Material m)
        {
            if (m == null) return null;
            foreach (var e in entries) if (e.source == m && e.animated != null) return e.animated;
            return m;
        }
    }
}
