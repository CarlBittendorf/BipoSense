include("../src/plot.jl")


types = ["Overall", "Prodromal", "DepressionProdromal", "ManiaProdromal", "DepressionEpisode", "ManiaEpisode"]

colors = [
    "KilometersFast" => BLUE,
    "IncomingMissedCalls" => ORANGE,
    "UniqueConversationPartners" => PURPLE,
    "MinutesDisplayOn" => LIGHTBLUE,
    "MinutesPhoneInactive" => RED,
    "MoodFixedLimits" => YELLOW,
    "Others" => GRAY
]

df_plot = @chain "data/BipoSense_Optimization.csv" begin
    CSV.read(DataFrame)
    stack("Sensitivity" .* types)
    rename(:variable => :SensitivityType, :value => :Value)
    transform(
        :SensitivityType => ByRow(x -> x[12:end]), # remove "Sensitivity" from the column name
        :Variable => ByRow(x -> x in first.(colors) ? x : "Others");
        renamecols=false
    )
end

# plot sensitivity against specificity
figure = draw(
    mapping(:Sensitivity, :Specificity) * visual(Lines; linestyle=:dash, linewidth=0.8) * (
        data((Sensitivity=[0.5, 0.5], Specificity=[0, 1])) +
        data((Sensitivity=[0, 1], Specificity=[0.95, 0.95]))
    ) +
    data((poly=[make_polygon([0.5, 1], [0.95, 0.95], [1, 1])],)) *
    mapping(:poly) * visual(Poly; color=GREEN, alpha=0.2) +
    data(df_plot) *
    mapping(
        :Value => "Sensitivity", :Specificity;
        layout=:SensitivityType => renamer(types .=> collect('a':'f') .* ") " .* types),
        color=:Variable => sorter(first.(colors))
    );
    axis=(width=300, height=200),
    palettes=(layout=reshape([(y, x) for x in 1:2, y in 1:3], :), color=last.(colors))
)

save("plots/Sensitivity_Specificity.png", figure, px_per_unit=3)