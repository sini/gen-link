# gen-link — the cross-flake aspect-federation conductor. Owns ONLY the origin coordinate, the
# disjoint-union-with-relabel, and the resolution manifest; delegates every computation to a sibling.
{
  prelude,
  scope,
  resolve,
  edge,
  schema,
  algebra,
  aspects,
}:
{
  # Modules land here as tasks complete. Marker proves the lib evaluates and wires deps.
  _scaffold = true;
}
