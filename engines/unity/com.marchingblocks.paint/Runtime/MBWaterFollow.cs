// MarchingBlocks Paint for Unity — WHEN THE WATER SHEET IS REBUILT (engines/PARITE.md §12, decided for the plugins):
//   - never during a gesture: a stroke only says the sheet is STALE;
//   - at the end of the gesture, after Calm seconds without a new one, a rebuild is due (off the main thread);
//   - a change that comes while a rebuild runs makes its result obsolete: it is not shown, another one follows the calm;
//   - the automatic follow CUTS ITSELF when the last rebuild took more than Cut seconds: the sheet stays stale until the
//     "Rebuild water" button (always there), which re-arms the follow when it is fast enough again.
// The clock is given by the caller: no Unity dependency (the .NET bench checks this rule).

namespace MarchingBlocks.Paint
{
    public sealed class MBWaterFollow
    {
        public const double Calm = 0.5;
        public const double Cut = 1.0;

        /// <summary>The automatic follow is wanted (the user's choice).</summary>
        public bool Enabled = true;
        /// <summary>The cells or the sources changed since the sheet shown was computed.</summary>
        public bool Stale { get; private set; }
        /// <summary>The follow cut itself: the last rebuild took more than Cut seconds.</summary>
        public bool CutOff { get; private set; }
        /// <summary>How long the last rebuild took (seconds), −1 before the first.</summary>
        public double LastSeconds { get; private set; } = -1;
        /// <summary>A rebuild is running.</summary>
        public bool Busy { get; private set; }

        double lastChange = double.NegativeInfinity;
        int generation, started;

        /// <summary>The cells or the sources changed (a stroke, an undo, an inspector edit).</summary>
        public void Changed(double now)
        {
            Stale = true;
            lastChange = now;
            generation++;
        }

        /// <summary>Should a rebuild start now? Never while a gesture is held, never twice at once, only after the calm.</summary>
        public bool Due(double now, bool gestureHeld) =>
            Enabled && !CutOff && Stale && !Busy && !gestureHeld && now - lastChange >= Calm;

        /// <summary>A rebuild starts (automatic or by the button); returns its ticket.</summary>
        public int Start()
        {
            Busy = true;
            started = generation;
            return started;
        }

        /// <summary>Is the result of this rebuild still the world's (no change since it started)?</summary>
        public bool Current(int ticket) => ticket == generation;

        /// <summary>A rebuild ended after <paramref name="seconds"/>. True when its result is still the world's (show it);
        /// false when a change came meanwhile (obsolete: the sheet stays stale, another rebuild follows).</summary>
        public bool Finished(int ticket, double seconds)
        {
            Busy = false;
            LastSeconds = seconds;
            CutOff = seconds > Cut;
            if (ticket != generation) return false;
            Stale = false;
            return true;
        }

        /// <summary>A rebuild failed (an exception): the sheet stays stale, nothing shown.</summary>
        public void Failed() => Busy = false;
    }
}
