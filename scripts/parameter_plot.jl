include("../src/plot.jl")


df_plot = @chain "data/BipoSense_Optimization.csv" begin
    CSV.read(DataFrame)
    filter(x -> x.Loss !== missing, _)
end

figure = draw(
    data(df_plot) * mapping(:Lambda => "λ", :L; layout=:Variable, color=:Loss);
    axis=(width=325, height=165), palettes=(layout=reshape([(y, x) for x in 1:3, y in 1:7], :),)
)

save("plots/Optimization_Parameters.png", figure, px_per_unit=3)