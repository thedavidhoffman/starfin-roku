// Expand the matrix into bounded in-memory suites before Rooibos discovers tests.
// Generated source is emitted only through the normal build/ and out/ pipeline.
const wireTypes = ['smalllibrarytiles', 'resume', 'resumeaudio', 'nextup', 'latestmedia', 'livetv'];
const rowKeys = ['libraries', 'continueWatching', 'continueListening', 'nextUp', 'latestMedia', 'liveTvOnNow'];

function* orderedSubsets(prefix = [], remaining = [0, 1, 2, 3, 4, 5]) {
  yield prefix;
  for (const index of remaining) {
    yield* orderedSubsets([...prefix, index], remaining.filter(value => value !== index));
  }
}

function parameterLines() {
  const lines = [];
  for (const subset of orderedSubsets()) {
    for (const combine of [false, true]) {
      const wire = subset.map(index => wireTypes[index]);
      const sections = subset.map(index => rowKeys[index]);
      const merged = combine && subset.includes(1) && subset.includes(3);
      // Independent oracle: remove the later watching slot, then replace the
      // earlier slot with the combined row identity.
      const expected = [...sections];
      if (merged) {
        const positions = [subset.indexOf(1), subset.indexOf(3)].sort((a, b) => a - b);
        expected.splice(positions[1], 1);
        expected[positions[0]] = 'continueWatching';
      }
      const args = [wire, sections, combine, expected, merged];
      lines.push('        @params(' + args.map(value => JSON.stringify(value)).join(', ') + ')');
    }
  }
  if (lines.length !== 3914) throw new Error('Home layout matrix must contain 3,914 cases');
  return lines;
}

module.exports = () => {
  let program;
  return {
    name: 'home-layout-exhaustive-cases',
    afterProgramCreate(value) { program = value; },
    beforeFileParse(source) {
      if (!source.srcPath.replace(/\\/g, '/').endsWith('/tests/rooibos/specs/source/HomeLayout.spec.bs')) return;
      const marker = "        ' HOME_LAYOUT_ORDERED_SUBSET_CASES";
      if (!source.source.includes(marker)) throw new Error('Home layout matrix marker is missing');
      const start = source.source.indexOf('        @describe("every ordered subset with combining on and off")');
      const end = source.source.indexOf('        @describe("sparse Jellyfin slots")', start);
      const template = source.source.slice(start, end);
      const body = template.slice(template.indexOf('        function _'));
      const lines = parameterLines();
      const batches = [];
      // Bound Rooibos metadata size: one enormous suite overflows BSC transpilation.
      for (let offset = 0; offset < lines.length; offset += 128) {
        const batch = offset / 128 + 1;
        batches.push([
          '    @suite("Home layout permutations batch ' + batch + '")',
          '    class HomeLayoutPermutationBatch' + batch + 'Tests extends rooibos.BaseTestSuite',
          '',
          '        @describe("ordered subsets")',
          '',
          '        @it("resolves every inclusion and ordering case")',
          ...lines.slice(offset, offset + 128),
          body,
          '    end class',
          ''
        ].join('\n'));
      }
      source.source = source.source.slice(0, start) + source.source.slice(end);
      batches.forEach((batch, index) => {
        program.setFile({
          src: require('node:path').join(program.options.rootDir, 'build/rooibos-fixtures/HomeLayoutBatch' + index + '.spec.bs'),
          dest: 'source/tests/generated/HomeLayoutBatch' + index + '.spec.bs'
        }, 'import "pkg:/source/HomeLayout.bs"\nnamespace tests\n' + batch + '\nend namespace');
      });
    }
  };
};
