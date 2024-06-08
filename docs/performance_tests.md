## Performance Testing

Here are the results of the performance tests between Jinja2, this library Julja2, and a library similar to Jinja2 written in Julia - Mustache.

### How Tests Were Conducted

I ran all tests on my local computer, not in the cloud. Several programs were running in the background alongside the script itself. I was not aiming for very accurate results, just a general comparison of the algorithms.

I ran all tests 100 times and calculated the mean results. Here is the code I used to run the tests:

```python
import timeit

template_str = "..."
my_obj = ...

def my_function():
    template = Template(template_str)
    return template.render(obj=my_obj)

times = timeit.repeat("my_function()", setup="from __main__ import my_function", repeat=100, number=1)

print(f"Mean execution time: {sum(times) / len(times) * 1000:.2f} ms")
```

```julia
using Pkg
Pkg.add("BenchmarkTools")

using BenchmarkTools

create_one_template_for_all_tests = # Mustache or Julja2

struct BenchmarkObj
    some_fields...
end
testing_obj = BenchmarkObj(...)

function my_function()
    or_create_template_each_time_again = # Mustache or Julja2
    render(template, testing_obj)
end

results = @benchmark my_function() samples=100
println("Mean execution time: ", mean(results).time / 1e6, " ms")
```

#### Tested Scenarios

I tested the following scenarios:
- Mustache: It has a method render (no method for separate template creation).
- Jinja2:
    - First variant with creation of a new template each test. Depending on the situation, if you can cache the compiled template, it will give better performance.
    - Second variant with caching the template.
- Julja2:
    - First variant with parsing the template string into generated code every time for each test.
    - Second variant with parsing the template only once.

### Variable Insertion

I ran each program on the same data set with different input amounts. It was simple variable insertion. Example:
`"{{ int_variable }}{{ int_variable }}....{{ int_variable }}"`.

There were three tests: 10 int variable insertions, 100 int variable insertions, and 1000 int variable insertions.

Here are the results:
I split the results into two groups - fast and slow. This is because if I put all the results on the same graph, it would not be representative. Some results were around 1 ms while others were around 200 ms, so differences in the 2-3 ms range would not be noticeable to the viewer.

![variable_insertion_slow_group](/docs/assets/variable_insertion_slow_group.png)
![variable_insertion_fast_group](/docs/assets/variable_insertion_fast_group.png)

As we can see, the difference between parsing the template each time for Julja2 is not that significant; in the 1000 case it is 40 ms, while for Jinja2 it is about 50 ms.

However, the overall time is dramatically slower, about 3 times slower than Jinja2 with new template parsing and approximately 150 times slower than Mustache and Jinja2 with a cached template.

### If Statements

Test data:
`"{% if true_statement %}some_string{% endif %}...{% if true_statement %}some_string{% endif %}"`.
Once again, test sets consisted of 10 if statements, 100 if statements, and 1000 if statements.

![if_condition_slow_group](/docs/assets/if_condition_slow_group.png)
![if_condition_fast_group](/docs/assets/if_condition_fast_group.png)

In these tests, we got similar results to variable insertion.

### For Loops

Test data:
`"{% for i in range(10) %}some_string{% endfor %}...{% for i in range(10) %}some_string{% endfor %}"`.
Test sets ranged from 10 for loops to 100 and 1000 for loops. They generated 10 times more strings than the number of for statements.

![for_operator_slow_group](/docs/assets/for_operator_slow_group.png)
![for_operator_fast_group](/docs/assets/for_operator_fast_group.png)

We found that Julja2 was a little bit faster compared to Jinja2 with template parsing (3 -> 2.3). Interestingly, Julja2 on small data sets was even faster than Jinja2 with template parsing.

Mustache is faster than Jinja2 with one template. Note that Mustache parses the template each time (I did not find caching in the source code), which is impressive.

## Overall Results

- Julja2 is slower than Jinja2 with template parsing by 2.3-3 times, but on small test data it could be even faster.
- Julja2 is slower than Jinja2 with a cached template and Mustache by about 100-200 times.
