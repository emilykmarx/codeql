// More test cases.  Some of these are inspired by real-world cases, others are synthetic or variations.

#define NULL 0

typedef struct {} FILE;
typedef struct {
	int foo;
} stat_data;

FILE *fopen(const char *filename, const char *mode);
int fclose(FILE *stream);

bool stat(const char *path, stat_data *buf);
void chmod(const char *path, int setting);
bool rename(const char *from, const char *to);
bool remove(const char *path);

bool access(const char *path);

// ---

void test1_1(const char *path)
{
	FILE *f = NULL;

	f = fopen(path, "r");

	if (f == NULL)
	{
		// retry
		f = fopen(path, "r"); // GOOD (this is just trying again) [FALSE POSITIVE]
	}

	// ...
}

void test1_2(const char *path)
{
	FILE *f = NULL;

	// try until we succeed
	while (f == NULL)
	{
		f = fopen(path, "r"); // GOOD (this is just trying again) [FALSE POSITIVE]

		// ...
	}

	// ...
}

// ---

void test2_1(const char *path)
{
	FILE *f = NULL;
	stat_data buf;

	if (stat(path, &buf))
	{
		f = fopen(path, "r"); // BAD
	}

	// ...
}

void test2_2(const char *path)
{
	FILE *f = NULL;
	stat_data buf;

	stat(path, &buf);
	if (buf.foo > 0)
	{
		f = fopen(path, "r"); // BAD [NOT DETECTED]
	}

	// ...
}

void test2_3(const char *path)
{
	FILE *f = NULL;
	stat_data buf;
	stat_data *buf_ptr = &buf;

	stat(path, buf_ptr);
	if (buf_ptr->foo > 0)
	{
		f = fopen(path, "r"); // BAD
	}

	// ...
}

bool stat_condition(const stat_data *buf);
bool other_condition();

void test2_4(const char *path)
{
	FILE *f = NULL;
	stat_data buf;

	stat(path, &buf);
	if (stat_condition(&buf))
	{
		f = fopen(path, "r"); // BAD [NOT DETECTED]
	}

	// ...
}

void test2_5(const char *path)
{
	FILE *f = NULL;
	stat_data buf;
	stat_data *buf_ptr = &buf;

	stat(path, buf_ptr);
	if (stat_condition(buf_ptr))
	{
		f = fopen(path, "r"); // BAD [NOT DETECTED]
	}

	// ...
}

void test2_6(const char *path)
{
	FILE *f = NULL;
	stat_data buf;

	stat(path, &buf);
	if (other_condition())
	{
		f = fopen(path, "r"); // GOOD (does not depend on the result of stat)
	}

	// ...
}

// ---

void test3_1(const char *path)
{
	FILE *f = NULL;

	f = fopen(path, "w");
	if (f)
	{
		// ...

		fclose(f);

		chmod(path, 0); // BAD
	}
}

void test3_2(const char *path)
{
	FILE *f = NULL;

	f = fopen(path, "w");
	if (f)
	{
		// ...

		fclose(f);
	}

	chmod(path, 0); // GOOD (doesn't depend on the fopen)
}

void test3_3(const char *path1, const char *path2)
{
	FILE *f = NULL;

	f = fopen(path1, "w");
	if (f)
	{
		// ...

		fclose(f);

		chmod(path2, 0); // GOOD (different file)
	}
}

// ---

void test4_1(const char *path1, const char *path2)
{
	if (!rename(path1, path2))
	{
		remove(path1); // BAD
	}
}

void test4_2(const char *path1, const char *path2)
{
	if (rename(path1, path2))
	{
		// ...
	} else {
		remove(path1); // BAD
	}
}

void test4_3(const char *path1, const char *path2)
{
	if (rename(path1, path2))
	{
		// ...
	}

	remove(path1); // GOOD (does not depend on the rename)
}

void test4_4(const char *path1, const char *path2)
{
	FILE *f = NULL;

	if (rename(path1, path2))
	{
		f = fopen(path2, "r"); // BAD [NOT DETECTED]
	}
}

// ---

void test5_1(const char *path)
{
	FILE *f = NULL;

	if (access(path))
	{
		f = fopen(path, "r"); // BAD
	}
}

void test5_2(const char *path)
{
	FILE *f = NULL;

	if (access(path))
	{
		// ...
	}

	f = fopen(path, "r"); // GOOD
}
